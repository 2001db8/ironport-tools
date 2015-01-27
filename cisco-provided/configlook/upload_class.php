<?php 
/*
Easy PHP Upload - version 2.31
A easy to use class for your (multiple) file uploads

Copyright (c) 2004 - 2006, Olaf Lederer
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the finalwebsites.com nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

______________________________________________________________________
available at http://www.finalwebsites.com/snippets.php
Comments & suggestions: http://www.webdigity.com/index.php/board,73.0.html,ref.olaf
*/
 
class file_upload {

    var $the_file;
	var $the_temp_file;
    var $upload_dir;
	var $replace;
	var $do_filename_check;
	var $max_length_filename = 100;
    var $extensions;
	var $ext_string;
	var $language;
	var $http_error;
	var $rename_file; // if this var is true the file copy get a new name
	var $file_copy; // the new name
	var $message = array();
	var $create_directory = true;
	
	function file_upload() {
		$this->language = "en"; // choice of en, nl, es
		$this->rename_file = false;
		$this->ext_string = "";
	}
	function show_error_string() {
		$msg_string = "";
		foreach ($this->message as $value) {
			$msg_string .= $value."<br />\n";
		}
		return $msg_string;
	}
	function set_file_name($new_name = "") { // this "conversion" is used for unique/new filenames 
		if ($this->rename_file) {
			if ($this->the_file == "") return;
			$name = ($new_name == "") ? strtotime("now") : $new_name;
			sleep(3);
			$name = $name.$this->get_extension($this->the_file);
		} else {
			$name = str_replace(" ", "_", $this->the_file); // space will result in problems on linux systems
		}
		return $name;
	}
	function upload($to_name = "") {
		$new_name = $this->set_file_name($to_name);
		if ($this->check_file_name($new_name)) {
			if ($this->validateExtension()) {
				if (is_uploaded_file($this->the_temp_file)) {
					$this->file_copy = $new_name;
					if ($this->move_upload($this->the_temp_file, $this->file_copy)) {
						$this->message[] = $this->error_text($this->http_error);
						if ($this->rename_file) $this->message[] = $this->error_text(16);
						return true;
					}
				} else {
					$this->message[] = $this->error_text($this->http_error);
					return false;
				}
			} else {
				$this->show_extensions();
				$this->message[] = $this->error_text(11);
				return false;
			}
		} else {
			return false;
		}
	}
	function check_file_name($the_name) {
		if ($the_name != "") {
			if (strlen($the_name) > $this->max_length_filename) {
				$this->message[] = $this->error_text(13);
				return false;
			} else {
				if ($this->do_filename_check == "y") {
					if (preg_match("/^[a-z0-9_]*\.(.){1,5}$/i", $the_name)) {
						return true;
					} else {
						$this->message[] = $this->error_text(12);
						return false;
					}
				} else {
					return true;
				}
			}
		} else {
			$this->message[] = $this->error_text(10);
			return false;
		}
	}
	function get_extension($from_file) {
		$ext = strtolower(strrchr($from_file,"."));
		return $ext;
	}
	function validateExtension() {
		$extension = $this->get_extension($this->the_file);
		$ext_array = $this->extensions;
		if (in_array($extension, $ext_array)) { 
			// check mime type hier too against allowed/restricted mime types (boolean check mimetype)
			return true;
		} else {
			return false;
		}
	}
	// this method is only used for detailed error reporting
	function show_extensions() {
		$this->ext_string = implode(" ", $this->extensions);
	}
	function move_upload($tmp_file, $new_file) {
		if ($this->existing_file($new_file)) {
			$newfile = $this->upload_dir.$new_file;
			if ($this->check_dir($this->upload_dir)) {
				if (move_uploaded_file($tmp_file, $newfile)) {
					umask(0);
					chmod($newfile , 0644);
					return true;
				} else {
					return false;
				}
			} else {
				$this->message[] = $this->error_text(14);
				return false;
			}
		} else {
			$this->message[] = $this->error_text(15);
			return false;
		}
	}
	function check_dir($directory) {
		if (!is_dir($directory)) {
			if ($this->create_directory) {
				umask(0);
				mkdir($directory, 0777);
				return true;
			} else { 
				return false;
			}
		} else {
			return true;
		}
	}
	function existing_file($file_name) {
		if ($this->replace == "y") {
			return true;
		} else {
			if (file_exists($this->upload_dir.$file_name)) {
				return false;
			} else {
				return true;
			}
		}
	}
	function get_uploaded_file_info($name) {
		$str = "File name: ".basename($name)."\n";
		$str .= "File size: ".filesize($name)." bytes\n";
		if (function_exists("mime_content_type")) {
			$str .= "Mime type: ".mime_content_type($name)."\n";
		}
		if ($img_dim = getimagesize($name)) {
			$str .= "Image dimensions: x = ".$img_dim[0]."px, y = ".$img_dim[1]."px\n";
		}
		return $str;
	}
	// this method was first located inside the foto_upload extension
	function del_temp_file($file) {
		$delete = @unlink($file); 
		clearstatcache();
		if (@file_exists($file)) { 
			$filesys = eregi_replace("/","\\",$file); 
			$delete = @system("del $filesys");
			clearstatcache();
			if (@file_exists($file)) { 
				$delete = @chmod ($file, 0644); 
				$delete = @unlink($file); 
				$delete = @system("del $filesys");
			}
		}
	}
	// this function creates a file field and if $show_alternate is true it will show a text field if the given file already exists
	// there is also a submit button to remove the text field value 
	function create_file_field($element, $label = "", $length = 25, $show_replace = true, $replace_label = "Replace old file?", $file_path = "", $file_name = "", $show_alternate = false, $alt_length = 30, $alt_btn_label = "Delete image") {
		$field = ($label != "") ? "<label>".$label."</label>\n" : "";
		$file_field = "<input type=\"file\" name=\"".$element."\" size=\"".$length."\" />\n";
		$file_field .= ($show_replace) ? "<span>".$replace_label."</span><input type=\"checkbox\" name=\"replace\" value=\"y\" />" : "";
		if ($file_name != "" && $show_alternate) {
			$field .= "<input type=\"text\" name=\"".$element."\" size=\"".$alt_length."\" value=\"".$file_name."\" readonly=\"readonly\"";
			$field .= (!@file_exists($file_path.$file_name)) ? " title=\"".sprintf($this->error_text(17), $file_name)."\" />\n" : " />\n";
			$field .= "<input type=\"checkbox\" name=\"del_img\" value=\"y\" /><span>".$alt_btn_label."</span>\n";
		} else {
			$field .= $file_field;
		} 
		return $field;
	}
	// some error (HTTP)reporting, change the messages or remove options if you like.
	function error_text($err_num) {
		switch ($this->language) {
			case "nl":
			$error[0] = "Foto succesvol kopieert.";
			$error[1] = "Het bestand is te groot, controlleer de max. toegelaten bestandsgrootte.";
			$error[2] = "Het bestand is te groot, controlleer de max. toegelaten bestandsgrootte.";
			$error[3] = "Fout bij het uploaden, probeer het nog een keer.";
			$error[4] = "Fout bij het uploaden, probeer het nog een keer.";
			$error[10] = "Selecteer een bestand.";
			$error[11] = "Het zijn alleen bestanden van dit type toegestaan: <b>".$this->ext_string."</b>";
			$error[12] = "Sorry, de bestandsnaam bevat tekens die niet zijn toegestaan. Gebruik alleen nummer, letters en het underscore teken. <br>Een geldige naam eindigt met een punt en de extensie.";
			$error[13] = "De bestandsnaam is te lang, het maximum is: ".$this->max_length_filename." teken.";
			$error[14] = "Sorry, het opgegeven directory bestaat niet!";
			$error[15] = "Uploading <b>".$this->the_file."...Fout!</b> Sorry, er is al een bestand met deze naam aanwezig.";
			$error[16] = "Het gekopieerde bestand is hernoemd naar <b>".$this->file_copy."</b>.";
			$error[17] = "Het bestand %s bestaat niet.";
			break;
			case "de":
			$error[0] = "Die Datei: <b>".$this->the_file."</b> wurde hochgeladen!"; 
			$error[1] = "Die hochzuladende Datei ist gr&ouml;&szlig;er als der Wert in der Server-Konfiguration!"; 
			$error[2] = "Die hochzuladende Datei ist gr&ouml;&szlig;er als der Wert in der Klassen-Konfiguration!"; 
			$error[3] = "Die hochzuladende Datei wurde nur teilweise &uuml;bertragen"; 
			$error[4] = "Es wurde keine Datei hochgeladen"; 
			$error[10] = "W&auml;hlen Sie eine Datei aus!."; 
			$error[11] = "Es sind nur Dateien mit folgenden Endungen erlaubt: <b>".$this->ext_string."</b>";
			$error[12] = "Der Dateiname enth&auml;lt ung&uuml;ltige Zeichen. Benutzen Sie nur alphanumerische Zeichen f&uuml;r den Dateinamen mit Unterstrich. <br>Ein g&uuml;ltiger Dateiname endet mit einem Punkt, gefolgt von der Endung."; 
			$error[13] = "Der Dateiname &uuml;berschreitet die maximale Anzahl von ".$this->max_length_filename." Zeichen."; 
			$error[14] = "Das Upload-Verzeichnis existiert nicht!"; 
			$error[15] = "Upload <b>".$this->the_file."...Fehler!</b> Eine Datei mit gleichem Dateinamen existiert bereits.";
			$error[16] = "Die hochgeladene Datei ist umbenannt in <b>".$this->file_copy."</b>.";
			$error[17] = "Die Datei %s existiert nicht.";
			break;
			//
			// place here the translations (if you need) from the directory "add_translations"
			//
			default:
			// start http errors
			$error[0] = "File: <b>".$this->the_file."</b> successfully uploaded!";
			$error[1] = "The uploaded file exceeds the max. upload filesize directive in the server configuration.";
			$error[2] = "The uploaded file exceeds the MAX_FILE_SIZE directive that was specified in the html form.";
			$error[3] = "The uploaded file was only partially uploaded";
			$error[4] = "No file was uploaded";
			// end  http errors
			$error[10] = "Please select a file for upload.";
			$error[11] = "Only files with the following extensions are allowed: <b>".$this->ext_string."</b>";
			$error[12] = "Sorry, the filename contains invalid characters. Use only alphanumerical chars and separate parts of the name (if needed) with an underscore. <br>A valid filename ends with one dot followed by the extension.";
			$error[13] = "The filename exceeds the maximum length of ".$this->max_length_filename." characters.";
			$error[14] = "Sorry, the upload directory doesn't exist!";
			$error[15] = "Uploading <b>".$this->the_file."...Error!</b> Sorry, a file with this name already exitst.";
			$error[16] = "The uploaded file is renamed to <b>".$this->file_copy."</b>.";
			$error[17] = "The file %s does not exist.";
		}
		return $error[$err_num];
	}
}






function insert_string_in_file($file,$insert_point,$string,$return=FALSE,$position='')
{
	// check if file exists
	if(!file_exists($file))
	{
		return($return === TRUE ? 'ERROR - file ('.$file.') does not exist' : FALSE);
	}
	// check if file is writeable
	if(!is_writeable($file))
	{
		return($return === TRUE ? 'ERROR - file ('.$file.') is not writeable' : FALSE);
	}
	// contruct insertion scheme
	if(empty($position))
	{
		// if nothing specified, replace the insertion point with string
		$replacement[$insert_point] = $string;
	}else{
		if($position == 'before')
		{
			// insert the string before the insertion point
			$replacement[$insert_point] = $string.$insert_point;
		}elseif($position == 'after')
		{
			// insert the string after the insertion point
			$replacement[$insert_point] = $insert_point.$string;
		}else{
			return($return === TRUE ? 'ERROR - position ('.$position.') is invalid - 
					use &quot;before&quot; or &quot;after&quot;' : FALSE);
		}
	}
	// check filelenght
	$filesize = filesize($file);
	clearstatcache();
	if($filesize == 0)
	{
		return ($return === TRUE ? 'ERROR - file ('.$file.') is empty' : FALSE);	
	}
	// open file for read and write access
	if(!$handle = fopen($file, 'r+'))
	{
		return($return === TRUE ? 'ERROR - cannot open file ('.$file.')' : FALSE);
	}else{
		$old_contents = fread($handle, $filesize);
	}
	// insert string at the insertion point
	if(!strpos($old_contents,$insert_point))
	{
		fclose($handle);
		return($return === TRUE ? 'ERROR - insertion point ('.$insert_point.') not found' : FALSE);
	}else{
		ftruncate($handle,0);
		$new_contents = strtr($old_contents,$replacement);
	}
	// write new content to file
	if(fwrite($handle, $new_contents) === FALSE)
	{
		fclose($handle);
		return ($return === TRUE ? 'ERROR - cannot write to file ('.$file.')' : FALSE);
	}
	fclose($handle);
	return($return === TRUE ? 'SUCCESS - your string was inserted' : TRUE);
}




?>