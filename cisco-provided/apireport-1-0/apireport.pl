#!/usr/bin/perl -w

use strict;
use Getopt::Std;
use LWP::UserAgent;
use lib::SWF::Chart;

my $main_config   = 'config/Primary_Config.txt';
my $host_config   = 'config/IronPort_Hostnames.txt';
my $report_config = 'config/Report_Config';

my ($chart, %csv_total, %swf_chart, %config, %report, @hosts);


###########################################################################
#
#  usage()
#
#  displays the various command-line switches to STDOUT.
#
###########################################################################

sub usage {

    print STDERR "usage: $0 [ -hv ] [ -g dir ] [ -H filename ] [ -R dir ] [ -C filename ]\n\n";
    print STDERR "\t-h : display help\n";
    print STDERR "\n";
    print STDERR "\t-g : report output directory (html/xml/flash)\n";
    print STDERR "\n";
    print STDERR "\t-C : primary configuration file (def. config/Primary_Config.txt)\n";
    print STDERR "\t-H : hosts to collect CSV data from (def. config/IronPort_Hostnames.txt)\n";
    print STDERR "\t-R : report configuration directory (def. config/Report_Config\n";
    print STDERR "\n";
}


###########################################################################
#
#  read_config(hashref, filename)
#
###########################################################################

sub read_config {

    my ($config, $main_config) = @_;

    open (MAINCONFIG, "<", $main_config)
        or die $!;

    my $input = \*MAINCONFIG;

    while (<$input>) {
    
        next unless /^[A-Z]/;
        chomp;
        s/ //;
        my ($var, $val) = split /=/;

        $config->{$var} = $val;
    }

    close MAINCONFIG;
}


###########################################################################
#
#  read_hosts(arrayref, filename)
#
###########################################################################

sub read_hosts {

    my ($hosts, $host_config) = @_;

    open (HOSTCONFIG, "<", $host_config)
        or die $!;

    my $input = \*HOSTCONFIG;

    while (<$input>) {
    
        next unless /^[1-9A-Za-z]/;
        chomp;
        s/ //;
        push (@{ $hosts }, $_);
    }

    close HOSTCONFIG;
}


###########################################################################
#
#  read_report_config(hashref, filename)
#
###########################################################################

sub read_report_config {

    my ($report, $report_config) = @_;

    open (REPORTCONFIG, "<", $report_config)
        or die $!;

    my $input = \*REPORTCONFIG;

    while (<$input>) {
    
        next unless /^[A-Za-z]/;
        chomp;
        my ($var, $val) = split /=/;

        if ($var =~ /COLUMN/) {
            push(@{ $report->{$var} }, $val);
        }
        else {
            $report->{$var} = $val;
        }

    }

    close REPORTCONFIG;
}


###########################################################################
#
#  assemble_url(hostname, hashref)
#
###########################################################################

sub assemble_url {

    my ($esa_hostname, $report) = @_;

    my $url;

    $url   .= $config{'PROTOCOL'} . '://';
    $url   .= $config{'ESA_LOGIN'} . ':' . $config{'ESA_PASSWORD'} . '@';
    $url   .= $esa_hostname . ':' . $config{'GUI_PORT'};

    $url   .= '/monitor/export?format=csv';

    $url   .= '&section='       . $report->{'SECTION'}; 
    $url   .= '&date_range='    . $report->{'REPORT_SPAN'};
    $url   .= '&report_def_id=' . $report->{'REPORT_DEF_ID'};

    return $url;
}


###########################################################################
#
#  download_csv_file(url, filename)
#
###########################################################################

sub download_csv_file {

    my ($csv_url, $csv_filename) = @_;

    my $http_agent  = LWP::UserAgent->new;
    my $api_request = HTTP::Request->new(GET => $csv_url);

    my $http_response = $http_agent->request($api_request, $csv_filename);

    if ($http_response->is_success) {
        return 0;
    }
    else {
        print "ERROR!\n";
        print $http_response->status_line, "\n\n";
        die "Cannot fetch CSV data from: " . $csv_url . "\n\n";
    }
}


###########################################################################
#
#  parse_csv_key(hashref, file, int)
#
#  parse a csv file, aggregating the data by a key (defined by third
#  parameter, which is the offset starting at 1 instead of 0).
#
#  All data to the left of the "key" column is basically ignored.
#
###########################################################################

sub parse_csv_key {

    my ($key_total, $csv_file, $keycol) = @_;  # keycol = offset, not index

    open (CSVFILE, "<", $csv_file)
        or die $!;
    my $input = \*CSVFILE;

    my @csv_header = split /,/, <$input>;

    chomp $csv_header[$#csv_header];
    splice(@csv_header, 0, $keycol);

    while (my @val = split /,/, <$input>) {

        my $key = $val[$keycol - 1];  # index, not offset, so -1

        chomp $val[$#val];
        splice(@val, 0, $keycol);

        foreach my $idx (0..$#csv_header) {
            $key_total->{$key}{$csv_header[$idx]} += $val[$idx];
        }
    }

    close CSVFILE;
}


###########################################################################
#
#  parse_csv_time(hashref, file, int, int)
#
#  parse a csv file, aggregating the data by a time period defined in
#  the third parameter.
#
#  86400 seconds = 1 day
#  3600 seconds  = 1 hour
#  .. etc.
#
#  if the csv data contains a non-numerical key in one column (to be
#  ignored), the fourth parameter should be changed from 4 to 5 (or 
#  whichever column contains the first 100% numerical data).
#
###########################################################################

sub parse_csv_time {

    my ($time_total, $csv_file, $rollup, $col) = @_;

    open (CSVFILE, "<", $csv_file)
        or die $!;
    my $input = \*CSVFILE;

    my @csv_header = split /,/, <$input>;

    chomp $csv_header[$#csv_header];
    splice(@csv_header, 0, $col);

    while (my @val = split /,/, <$input>) {

        my $tz_time;

        if ($rollup > 0) {
            $tz_time = int($val[0] / $rollup) * $rollup - ($config{'GMT_OFFSET'} * 3600);
        }
        else {
            $tz_time = 0;
        }

        chomp $val[$#val];
        splice(@val, 0, $col);

        foreach my $idx (0..$#csv_header) {
            $time_total->{$tz_time}{$csv_header[$idx]} += $val[$idx];
        }
    }

    close CSVFILE;
}


###########################################################################
#
#  sort_csv_subtotals(hashref, int, int)
#
#  sort the hash and push the values into an array
#  for the chart(s)
#
#  note: pie charts (or any other chart with a single "dataset"
#        must be handled in reverse.  columns become rows and
#        vice versa.
#
###########################################################################

sub sort_csv_total {

    my ($csv_total, $swf_chart, $report) = @_;

    if ($report->{'CHART_TYPE'} =~ /Pie/) {
        foreach my $column (@{ $report->{'COLUMN'} }) {
            push (@{ $swf_chart->{'TITLES'} }, $column);
            foreach my $key (sort { $a <=> $b } keys %{ $csv_total }) {
                push (@{ $swf_chart->{$key} }, $csv_total->{$key}{$column});
            }
        }
    }
    else {
        foreach my $key (sort { $a <=> $b } keys %{ $csv_total }) {
            my ($s, $m, $hr, $mday, $mn, $yr, $wd, $yd, $dst) = localtime($key);
            push (@{ $swf_chart->{'TITLES'} }, ($yr + 1900) . '/' . ($mn + 1) . '/' . $mday);
            foreach my $column (@{ $report->{'COLUMN'} }) {
                push (@{ $swf_chart->{$column} }, $csv_total->{$key}{$column});
            }
        }
    }
}

###########################################################################
#
#  gen_chart(filename, path, filename, int, int, hex)
#
###########################################################################

sub gen_chart {

    my ($csv_total, $swf_chart, $report) = @_;

    $chart = SWF::Chart->new;

    if ($report->{'CHART_TYPE'} =~ /Pie/) {
        pie_chart($report);
        $chart->set_titles(\@{ $swf_chart->{'TITLES'} });
        foreach my $key (sort { $a <=> $b } keys %{ $csv_total }) {
            $chart->add_dataset($key => \@{ $swf_chart->{$key} });
        }
    }
    else {
        default_chart($report);
        $chart->set_titles(\@{ $swf_chart->{'TITLES'} });
        foreach my $column (@{ $report->{'COLUMN'} }) {
            $chart->add_dataset($column => \@{ $swf_chart->{$column} });
        }
    }

    return $chart->xml;
}


###########################################################################
#
#  insert_chart(filename, path, filename, int, int, hex)
#
###########################################################################

sub gen_chart_html {

    my ($flash_file, $lib_path, $xml_source, $width, $height, $bg_color) = @_;
    
    my $html;
    #my $license = "F1XIJ7CHWH7L.NS5T4Q79KLYCK07EK";

    $html .= "<object classid='clsid:D27CDB6E-AE6D-11cf-96B8-444553540000'";
    $html .= "codebase='http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,0,0' ";
    $html .= "width=" . $width . " height=" . $height . " id='charts' align=''>";
    $html .= "<param name=movie value='" . $flash_file . '?' . "library_path=" . $lib_path . "&xml_source=" . $xml_source;
    #$html .= "&license=" . $license;
    $html .= "'> <param name=quality value=high> <param name=bgcolor value=#" . $bg_color . "> ";
    $html .= "<embed src='" . $flash_file . "?" . "library_path=" . $lib_path . "&xml_source=" . $xml_source;
    #$html .= "&license=" . $license;
    $html .= "' quality=high bgcolor=#" . $bg_color . " width=" . $width . " height=" . $height;
    $html .= " name='charts' align='' swLiveConnect='true' ";
    $html .= "type='application/x-shockwave-flash' pluginspage='http://www.macromedia.com/go/getflashplayer'></embed></object>";
    $html .= "<br>\n";

    return $html;
    
}


###########################################################################
#
#  main()
#
###########################################################################

print "\n";

getopts('hvC:R:H:g:', \my %opt);

usage and exit(0)
    if $opt{h};

read_config(\%config, defined $opt{C} ? $opt{C} : $main_config);
read_hosts(\@hosts, defined $opt{H} ? $opt{H} : $host_config);

opendir(CHARTCONF, defined $opt{R} ? $opt{R} : $report_config)
    or die $!;

open (HTMLOUT, ">", $config{'REPORT_DIR'} . '/index.html')
    or die $!;

foreach my $file (grep { /^[0-9][0-9]_Chart/ } readdir(CHARTCONF)) {

    print "Processing ... " . $file . "\n";
    
    undef %report;
    undef %csv_total;
    undef %swf_chart;

    read_report_config(\%report, (defined $opt{R} ? $opt{R} : $report_config) . '/' . $file);

    foreach my $hostname (@hosts) {

        download_csv_file(assemble_url($hostname, \%report), $config{'TEMP_CSV'});

        if ($report{'GROUP'} =~ /time/) {
            parse_csv_time(\%csv_total, $config{'TEMP_CSV'}, $report{'ROLLUP'}, 4);
        }
        elsif ($report{'GROUP'} =~ /key/) {
            parse_csv_key(\%csv_total, $config{'TEMP_CSV'}, 5);
        }
        else {
            die 'ERROR!  Missing "GROUP" parameter in report configuration file!';
        }
    }

    unlink($config{'TEMP_CSV'});

    open (XMLOUT, ">", $config{'REPORT_DIR'} . '/' . $report{'XML_FILE'})
        or die $!;

    sort_csv_total(\%csv_total, \%swf_chart, \%report);
    print XMLOUT gen_chart(\%csv_total, \%swf_chart, \%report);
    print HTMLOUT gen_chart_html('charts.swf', 'charts', $report{'XML_FILE'}, $report{'WIDTH'}, $report{'HEIGHT'}, $report{'BGCOLOR'});

    close XMLOUT;
}

print "\n";

closedir CHARTCONF;
close HTMLOUT;


###########################################################################
#
#  chart configurations
#
###########################################################################


sub default_chart {

    my $report = shift;

    $chart->chart_type($report->{'CHART_TYPE'});

    #############################################################################################

    $chart->axis_category(

            "size"              => 8,
            "color"             => "000000",
            "alpha"             => 50,
            "font"              => "arial",
            "bold"              => "true",
            "skip"              => 3,
            "orientation"       => "horizontal"

    ); 

    #############################################################################################

    $chart->axis_ticks(

            "value_ticks"       => "true",
            "category_ticks"    => "true",
            "major_thickness"   => 1,
            "minor_thickness"   => 1,
            "minor_count"       => 1,
            "major_color"       => "9f9f9f",
            "minor_color"       => "c0c0c0" ,
            "position"          => "outside"
            
    );

    #############################################################################################

    $chart->axis_value(

            "min"               => 0,
            "font"              => "arial",
            "bold"              => "true",
            "size"              => 8,
            "color"             => "000000",
            "alpha"             => 50,
            "steps"             => 4,
            "prefix"            => "",
            "suffix"            => "",
            "decimals"          => 0,
            "separator"         => ",",
            "show_min"          => "true"

    );

    #############################################################################################

    $chart->chart_border(
            
            "color"             => "999999",
            "top_thickness"     => 1,
            "bottom_thickness"  => 1,
            "left_thickness"    => 1,
            "right_thickness"   => 1 

    );

    #############################################################################################

    $chart->chart_grid_h(

            "alpha"             => 10,
            "color"             => "000000",
            "thickness"         => 1,
            "type"              => "solid"

    );

    #############################################################################################

    $chart->chart_grid_v(

            "alpha"             => 2,
            "color"             => "000000",
            "thickness"         => 1,
            "type"              => "solid"

    );

    #############################################################################################

    $chart->chart_pref(

            "line_thickness"    => 2,
            "point_shape"       => "none",
            "fill_shape"        => "false"

    );

    #############################################################################################

    $chart->chart_rect(

            "x"                 => 40,
            "y"                 => 100,
            "width"             => 590,
            "height"            => 200,
            "positive_color"    => "999999",
            "positive_alpha"    => 20,
            "negative_color"    => "ff0000",
            "negative_alpha"    => 10

    );

    #############################################################################################

    $chart->chart_value(

            "prefix"            => "",
            "suffix"            => " recipients",
            "decimals"          => 0,
            "separator"         => ",",
            "position"          => "cursor",
            "hide_zero"         =>"true",
            "as_percentage"     => "false",
            "font"              => "arial",
            "bold"              =>"true",
            "size"              => 12,
            "color"             => "333333",
            "alpha"             => 75

    );

    #############################################################################################

    $chart->draw_text(

            $report->{'TITLE_B'},

            "color"             => "666666",
            "alpha"             => 50,
            "font"              => "arial",
            "rotation"          => 0,
            "bold"              => "true",
            "size"              => 32,
            "x"                 => 40,
            "y"                 => 30,
            "width"             => 250,
            "height"            => 100,
            "h_align"           => "left",
            "v_align"           => "top"

    );

    $chart->draw_text(

            $report->{'TITLE_A'},

            "color"             => "c0c0c0",
            "alpha"             => 75,
            "font"              => "arial",
            "rotation"          => 0,
            "bold"              => "true",
            "size"              => 30,
            "x"                 => 10,
            "y"                 => 0,
            "width"             => 250,
            "height"            => 100,
            "h_align"           => "left",
            "v_align"           => "top"

    );


    #############################################################################################

    $chart->legend_rect(

            "x"                 => 270,
            "y"                 => 50,
            "width"             => 360,
            "height"            => 10,
            "margin"            => 4,
            "fill_color"        => "999999",
            "fill_alpha"        => 20,
            "line_color"        => "000000",
            "line_alpha"        => 50 

    ); 

    #############################################################################################

    $chart->legend_label(

            "layout"            => "horizontal",
            "bullet"            => "square",
            "font"              => "arial",
            "bold"              => "true",
            "size"              => 10,
            "color"             => "333333",
            "alpha"             => 85

    ); 

    #############################################################################################

    $chart->series_color("26526C");
    $chart->series_color("7A1D15");
    $chart->series_color("CF9334");
    $chart->series_color("6A3D2C");
    $chart->series_color("4B6496");
    $chart->series_color("2C2C6C");

    #############################################################################################

}


sub pie_chart {

    my $report = shift;

    $chart->chart_type("Pie");

    #############################################################################################

    $chart->chart_border(
            
            "color"             => "000",
            "top_thickness"     => 0,
            "bottom_thickness"  => 0,
            "left_thickness"    => 0,
            "right_thickness"   => 0 

    );

    #############################################################################################

    $chart->chart_grid_h(

            "alpha"             => 0,
            "color"             => "000000",
            "thickness"         => 0,
            "type"              => "solid"

    );

    #############################################################################################

    $chart->chart_grid_v(

            "alpha"             => 0,
            "color"             => "000000",
            "thickness"         => 0,
            "type"              => "solid"

    );

    #############################################################################################

    $chart->chart_rect(

            "x"                 => 0,
            "y"                 => 50,
            "width"             => 300,
            "height"            => 250,
            "positive_color"    => "999999",
            "positive_alpha"    => 0,
            "negative_color"    => "333333",
            "negative_alpha"    => 0 

    );

    #############################################################################################

    $chart->chart_value(

            #"prefix"            => "",
            #"suffix"            => "%",
            "decimals"          => 0,
            "separator"         => ",",
            "position"          => "cursor",
            "hide_zero"         => "true",
            "as_percentage"     => "false",
            "font"              => "arial",
            "bold"              => "true",
            "size"              => 24,
            "color"             => "000000",
            "alpha"             => 65

    );

    #############################################################################################

    $chart->draw_text(

            $report->{'TITLE_B'},

            #"transition"        => "slide_left",
            "color"             => "666666",
            "alpha"             => 50,
            "font"              => "arial",
            "rotation"          => 0,
            "bold"              => "true",
            "size"              => 34, 
            "x"                 => 240,
            "y"                 => 50,
            "width"             => 260,
            "height"            => 140,
            "h_align"           => "center",
            "v_align"           => "top"

    ); 

    $chart->draw_text(

            $report->{'TITLE_A'},

            #"transition"        => "slide_right",
            "color"             => "c0c0c0",
            "alpha"             => 75,
            "font"              => "arial",
            "rotation"          => 0,
            "bold"              => "true",
            "size"              => 32,
            "x"                 => 200,
            "y"                 => 20,
            "width"             => 260,
            "height"            => 140,
            "h_align"           => "center",
            "v_align"           => "top"

    ); 

    #############################################################################################

    $chart->legend_rect(

            "x"                 => 300,
            "y"                 => 120,
            "width"             => 200,
            "height"            => 100,
            "margin"            => 4,
            "fill_color"        => "999999",
            "fill_alpha"        => 20,
            "line_color"        => "000000",
            "line_alpha"        => 50 

    ); 

    #############################################################################################

    $chart->legend_label(

            "layout"            => "vertical",
            "bullet"            => "square",
            "font"              => "arial",
            "bold"              => "true",
            "size"              => 10,
            "color"             => "333333",
            "alpha"             => 85

    ); 

    #############################################################################################

    $chart->series_color("26526C");
    $chart->series_color("7A1D15");
    $chart->series_color("CF9334");
    $chart->series_color("6A3D2C");
    $chart->series_color("4B6496");
    $chart->series_color("2C2C6C");

    $chart->series_explode($report->{'EXPLODE'});
    $chart->series_explode($report->{'EXPLODE'});
    $chart->series_explode($report->{'EXPLODE'});
    $chart->series_explode($report->{'EXPLODE'});
    $chart->series_explode($report->{'EXPLODE'});
    $chart->series_explode($report->{'EXPLODE'});

    #############################################################################################

}
