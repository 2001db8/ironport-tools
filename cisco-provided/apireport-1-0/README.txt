===========================================================================
 IronPort Systems + 5.0 Reporting API Tools      (c) IronPort Systems 2007
===========================================================================

  ----------------------------------------------------------------------
    Overview
  ----------------------------------------------------------------------

    This package contains tools that can be used for processing mail
    flow data retrieved from IronPort appliances through the AsyncOS
    Reporting API that is available in AsyncOS 5.0.  These tools are
    provided with source code under the GNU Public License for the use
    of IronPort customers to extend and modify as they need.



  ----------------------------------------------------------------------
    Files 
  ----------------------------------------------------------------------

        config/           : Configuration directory
        doc/              : API Reference Material
        tmp/              : "TEMP" location used for CSV transfers
        output/           : Default report output directory
        apireport.pl      : Main program
        README.txt        : This file
        COPYING.txt       : GNU Public License

        config/Primary_Config.txt         : Primary configuration file
        config/IronPort_Hostnames.txt     : List of appliances
        config/Report_Config/??_Chart.txt : Chart configuration files *

        output/chart/                     : Chart library files **
        output/index.html                 : HTML report index page
        output/chart??.xml                : XML chart output

        lib/SWF/Chart.pm                  : SWF::Chart Perl module

            
            * you may add as many new chart configuration files
              as you like.

           ** XML/SWF Charts - http://www.maani.us/xml_charts/

  ----------------------------------------------------------------------
    Perl Modules
  ----------------------------------------------------------------------

    Certain Perl distributions may need to install additional Perl
    modules before apireport.pl will work properly.

      LWP::UserAgent : This module is required for HTTPS downloads.
                       It is included with ActivePerl, but not with
                       some other Perl distributions.


      Crypt::SSLeay  : ActivePerl users in particular will need to
                       install this module.  The following URLs may
                       be used, at your own risk, to download this
                       module (note: corresponding version numbers
                       included).

 Perl 5.8.x :
  ppm install http://theoryx5.uwinnipeg.ca/ppms/Crypt-SSLeay.ppd
                         

 Perl 5.6.x :
  ppm install http://theoryx5.uwinnipeg.ca/ppmpackages/Crypt-SSLeay.ppd



  ----------------------------------------------------------------------
    License 
  ----------------------------------------------------------------------

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or (at
    your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
    USA



===========================================================================

===========================================================================
