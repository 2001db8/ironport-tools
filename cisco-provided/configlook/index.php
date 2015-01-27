<?php
include ("upload_class.php"); //classes is the map where the class file is stored (one above the root)

$max_size = 20480*1000; // the max. size for uploading
	
$my_upload = new file_upload;

$my_upload->upload_dir = "./files/"; // "files" is the folder for the uploaded files (you have to create this folder)
$my_upload->extensions = array(".xml"); // specify the allowed extensions here , ".xxx"
// $my_upload->extensions = "de"; // use this to switch the messages into an other language (translate first!!!)
$my_upload->max_length_filename = 200; // change this value to fit your field length in your database (standard 100)
$my_upload->rename_file = false;
		
if(isset($_POST['submitting'])) {
	$my_upload->the_temp_file = $_FILES['upload']['tmp_name'];
	$my_upload->the_file = $_FILES['upload']['name'];
	$my_upload->http_error = $_FILES['upload']['error'];
	$my_upload->replace = (isset($_POST['replace'])) ? $_POST['replace'] : "n"; // because only a checked checkboxes is true
	$my_upload->do_filename_check = (isset($_POST['check'])) ? $_POST['check'] : "n"; // use this boolean to check for a valid filename
	$new_name = (isset($_POST['name'])) ? $_POST['name'] : "";
	if ($my_upload->upload($new_name)) { // new name is an additional filename information, use this to rename the uploaded file
		$full_path = $my_upload->upload_dir.$my_upload->file_copy;
		$info = $my_upload->get_uploaded_file_info($full_path);
		// ... or do something like insert the filename to the database
	}
}
?> 
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
	
<head>
	<title>Ironport Configuration Viewr</title>
	<style type="text/css" media="all">
	
	body {
		 font-size: 87.5%;
         font-family: "Trebuchet MS", Trebuchet, Verdana, Helvetica, Arial, sans-serif;
	}
	
	fieldset {
		padding: 0 1em 1em 1em;
	}
	
	legend {
		color: #00CCFF;
		font-size: 1.74em;
		padding: 1em;
	}
	
	.fieldtable {
		border: 0px;
		padding: 2px;
		margin: 0px;
		width: 100%;
		min-width: 700px;
	}
	
	.featuretable {
		border: 1px solid #e0e0e0;
		padding: 2px;
		margin: 0px;
		width: 90%;
	}
	.alt {
		background-color: #e0e0e0;
	}
	.firstrow {
		width: 300px;
		vertical-align: top;
	}
	
	.secondrow {
		width: 350px;
	}
	.thirdrow {
		width: 50px;
		text-align: right;
		
	}
	h4 {
		font-size: 1.25em;
		margin-bottom: 3px;
		color: #0CCB45;
	}
	.fieldid {
		text-align: left;
		font-weight: bold;
	}
	.tableheading {
		font-weight: bold;
		font-size: 1.15em;
		color: #ff0033;
		margin-bottom: 5px;
	}
	.warning {
		background-color: #FFD3C5;
		color: RED;
		padding: 5px;
		font-weight: bold;
		width: 50%;
		margin-left: 25%;
		border: 1px dashed blue;
	}
	.infotext {
		color: green;
		font-size: 0.73em;
	}
	.comingsoontext {
		color: #009ACD;
		font-size: 0.83em;
	}
	.boxid {
		color: #707070;
		font-size: 12px;
		font-weight: bold;
		font-family: "Courier New", Courier, fixed;
	}
	#footer {
		margin-top: 10px;
		text-align: center;
	}
	</style>
	

	<script src="inc/jquery-1.1.3.1.pack.js" type="text/javascript"></script>
	<script language="JavaScript" type="text/javascript">
		
			 $(document).ready(function() {
   				

				
				
				$('#submitbutton').click(function() {
					$('#submitbutton').attr("disabled","disabled");
					$('#form1').submit();
				});
					
					
			});
	</script>	
</head>

<body>



	<?php 
	if ($_SERVER["SERVER_NAME"] != 'www.ironportnation.com') {
	?>
	<br><br>
	<div style="background-color:#FBFF94; border: 1px dashed blue; padding: 5px; color:#D95C56; font-size: 1.3em; margin-left: 10px;">
	<span class="boxid">NOTICE</span><br />
	This is not a production app. Please use this instead <a href="https://www.ironportnation.com/forums/configlook/">https://www.ironportnation.com/forums/configlook/</a></div>

	
	<?php
	}
	?>



<form name="form1" id="form1" enctype="multipart/form-data" method="post" action="<?php echo $_SERVER['PHP_SELF']; ?>">
  <input type="hidden" name="submitting" value="y" />
  <input type="hidden" name="replace" value="y" />
  <input type="hidden" name="MAX_FILE_SIZE" value="<?php echo $max_size; ?>" />

<fieldset>

<legend>Ironport Configuration Viewr</legend>



<?php 

if (isset($info)) {

// echo "<blockquote>".nl2br($info)."</blockquote>";


 if(isset($_POST['submitting'])) {
	
 /* $the_file = $full_path;
 $insert_key = '<!DOCTYPE config SYSTEM "config.dtd">';

 $new_data =  "<?xml-stylesheet type=\"text/xsl\" href=\"process.xslt\"?>". "\n";

 //insert string before insertion point and get verbose messages
 insert_string_in_file($the_file,$insert_key,$new_data,TRUE,'before');

	
	


 echo "<br />File updated <a href=\"".$full_path."\">open</a> <br />";  
*/
$the_file = $full_path;
$fp=fopen($the_file,'r');
$content=fread($fp,filesize($the_file));
fclose($fp);

$IP_Product = '';
$IP_Model = '';
$IP_Version = '';
$IP_Serial = '';
$IP_CPUs = 0;
$IP_Memory = 0;
$IP_CurTime = '';
$IP_Features = array();

$pattern = "/\<![ \r\n\t]*(--([^\-]|[\r\n]|-[^\-])*--[ \r\n\t]*)\>/";

preg_match_all($pattern, $content, $matches, PREG_SET_ORDER);


$matchcontent = str_replace("--","",$matches[0][1]);

$arry_names = split("[\n|\r]", $matchcontent);
foreach ($arry_names as $key => $value) {
	$potentialkey = split(":", $value);
    //echo "Key: $key; Value: $value<br />\n";
	//echo "--->".$potentialkey[0]." = ".$potentialkey[1]."<br />";
	
	if (trim($potentialkey[0]) === 'Product') {
		$IP_Product = trim($potentialkey[1]);
	}
	if (trim($potentialkey[0]) === 'Model Number') {
		$IP_Model = trim($potentialkey[1]);
	}
	if (trim($potentialkey[0]) === 'Version') {
		$IP_Version = trim($potentialkey[1]);
	}
	if (trim($potentialkey[0]) === 'Serial Number') {
		$IP_Serial = trim($potentialkey[1]);
	}
	if (trim($potentialkey[0]) === 'Number of CPUs') {
		$IP_CPUs = trim($potentialkey[1]);
	}
	if (trim($potentialkey[0]) === 'Memory (GB)') {
		$IP_Memory = trim($potentialkey[1]);
	}
	if (trim($potentialkey[0]) === 'Current Time') {
		$IP_CurTime = trim($potentialkey[1]) . ":" . trim($potentialkey[2]) . ":" . trim($potentialkey[3]);
	}
	if (substr(trim($potentialkey[0]),0,7) === 'Feature') {
		array_push($IP_Features, trim($potentialkey[0]).":".trim($potentialkey[1]));
	}
	
	
}


//<!DOCTYPE config SYSTEM "config.dtd">
$content = str_replace("<!DOCTYPE config SYSTEM \"config.dtd\">","<?xml-stylesheet type=\"text/xsl\" href=\"../process.xslt\"?>\n",$content);



$fh = fopen($the_file, 'w') or die("can't open file");
fwrite($fh, $content);
fclose($fh);
?>
<h4>View Configuration Details</h4>

<table class="fieldtable">
	<tr>
		<td class="firstrow">
			<label for="upload">Upload Successful</label><br />
			<br /><a href="index.php">Upload another config file</a>
		</td>
		<td>
			<?php echo "View <a href=\"".$full_path."\" target=\"_blank\">".$my_upload->the_file."</a> "; ?>
		</td>
	</tr>
	
	

</table>

<h4>Upload Summary</h4>
<table class="fieldtable">
	<tr>
		<td style="width:50%">
			<span class="tableheading">System Info</span><br />
			<table class="featuretable">
				<tr>
					<td class="fieldid">Product:</td>
					<td><?php echo $IP_Product ?></td>
				</tr>
				<tr class="alt">
					<td class="fieldid">Model:</td>
					<td><?php echo $IP_Model ?></td>
				</tr>
				<tr>
					<td class="fieldid">Version:</td>
					<td><?php echo $IP_Version ?></td>
				</tr>
				<tr class="alt">
					<td class="fieldid">Serial Number:</td>
					<td><?php echo $IP_Serial ?></td>
				</tr>
				<tr>
					<td class="fieldid">Number of CPUs:</td>
					<td><?php echo $IP_CPUs ?></td>
				</tr>
				<tr class="alt">
					<td class="fieldid">GB of Memory:</td>
					<td><?php echo $IP_Memory ?></td>
				</tr>
				<tr>
					<td class="fieldid">Time Generated (local):</td>
					<td><?php echo $IP_CurTime ?></td>
				</tr>
			</table>

		</td>
		<td>
			
			<span class="tableheading">System Features</span><br />
			<table class="featuretable">
			<?php
				$flip = 0;
				foreach ($IP_Features as $key => $value)  {
						$potentialkey = split(":", $value);
						$fieldname = trim($potentialkey[0]);
						$fieldname = str_replace("Feature \"","",$fieldname);
						$fieldname = str_replace("\"","",$fieldname);
				?>
				<?php
				if (fmod($flip, 2) == 0) { 
				?>
					<tr>
				<?php } else { ?>
					<tr class="alt">
				<?php
				}
				?>
					<td class="fieldid"><?php echo $fieldname ?></td>
					<td><?php echo $potentialkey[1] ?></td>
				</tr>
				<?php
				
						$flip++;
	
				}
			?>
			</table>

		</td>
	</tr>
</table>




<?php


}

} else {
	
?> 

	<?php
	 if(isset($_POST['submitting'])) { 
	?>
	<div class="warning">
	<span class="boxid">ERROR</span><br />
	<?php echo $my_upload->show_error_string(); ?></div>
	<?php
	 }
	?>
	
<table class="fieldtable">
	<tr>
		<td class="firstrow" rowspan="2">
			<label for="upload">Upload your <a href="http://www.ironport.com/products/email_security_appliances.html">C/X-series</a>, <a href="http://www.ironport.com/products/web_security_appliances.html">S-series</a>, <a href="http://www.ironport.com/products/security_management_appliances.html">M-series</a>
			<br /> or <a href="http://ironport.com/technology/ironport_pxe_encryption.html">IEA</a> .xml config file:</label>
		<br /><br />
		<span class="comingsoontext">Clustered Appliance support coming soon</span>
		</td>
		<td class="secondrow">
			<input type="file" name="upload" size="30">
		</td>
		<td class="thirdrow">
			<input style="margin-right:20px;" type="button" name="submitbutton" id="submitbutton" value="Submit">
		</td>
	</tr>
	
	<tr>
		<td colspan="2">
			<!--<span class="infotext">Max. filesize = <?php echo $max_size; ?> bytes.</span>-->
			<span class="infotext">Max filesize 20 MB</span>
			<br /><br />
			<input type="checkbox" name="allowperm" id="allowperm" /> <label for="allowperm">Create a permanent link to this file</label>
		
		</td>

	</tr>
	

</table>

	
<?php
}

 ?> 


</fieldset>

<div id="footer">

&copy; Ironport 2007 - <a href="mailto:jforsythe@ironport.com">support</a>
	
</div>


</form>



</body>
</html>



