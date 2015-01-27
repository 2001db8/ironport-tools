<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">



<xsl:template match="/">

<html lang="en">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <meta http-equiv="Content-Style-Type" content="text/css" />
        <meta http-equiv="Content-Script-Type" content="text/javascript" />
		
		<title>Ironport Configuration Viewr</title>
 		
		<script src="../inc/jquery-1.1.3.1.pack.js" type="text/javascript"></script>
        <script src="../inc/jquery.history_remote.pack.js" type="text/javascript"></script>
        <script src="../inc/jquery.tabs.pack.js" type="text/javascript"></script>
		
        <script type="text/javascript">
           
			$(function() {

                $('#TABS').tabs();
				$('#listenercontainer').tabs();

					<xsl:for-each select="config/listeners/listener">
				    <xsl:variable name="cur" select='position()' />
						$('#list_container_<xsl:value-of select="$cur"/>').tabs();		
					</xsl:for-each>
                


            });

			function do_print() {
	
				
				 window.print();
				
			}

        </script>

        <link rel="stylesheet" href="../inc/jquery.tabs.css" type="text/css" media="print, projection, screen" />
        <!-- Additional IE/Win specific style sheet (Conditional Comments) -->
       
		 <!--[if lte IE 7]>
        <link rel="stylesheet" href="../inc/jquery.tabs-ie.css" type="text/css" media="projection, screen">
        <![endif]-->



        <style type="text/css" media="screen, projection">

 			body {
                font-size: 16px; /* @ EOMB */
            }
            * html body {
                font-size: 100%; /* @ IE */
            }
            body * {
                font-size: 87.5%;
                font-family: "Trebuchet MS", Trebuchet, Verdana, Helvetica, Arial, sans-serif;
            }
            body * * {
                font-size: 100%;
            }
            h1 {
                margin: 1em 0 1.5em;
                font-size: 18px;
				color: #EE7A28;
            }
            h2 {
                margin: 2em 0 1.5em;
                font-size: 16px;
            }
            p {
                margin: 0;
            }
            pre, pre+p, p+p {
                margin: 1em 0 0;
            }
            code {
                font-family: "Courier New", Courier, monospace;
            }





			.datatable {
				width: 75%;
				padding: 0;
				margin: 0;
			}
			
			caption {
				padding: 0 0 5px 0;
				width: 75%;	 
				font: italic 11px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
				text-align: right;
			}
			
			th {
				font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
				color: #4f6b72;
				border-right: 1px solid #C1DAD7;
				border-bottom: 1px solid #C1DAD7;
				border-top: 1px solid #C1DAD7;
				letter-spacing: 2px;
				text-transform: uppercase;
				text-align: left;
				padding: 6px 6px 6px 12px;
				background: #CAE8EA url(images/bg_header.jpg) no-repeat;
			}
			
			th.nobg {
				border-top: 0;
				border-left: 0;
				border-right: 1px solid #C1DAD7;
				background: none;
			}
			
			td {
				border-right: 1px solid #C1DAD7;
				border-bottom: 1px solid #C1DAD7;
				background: #fff;
				padding: 6px 6px 6px 12px;
				color: #4f6b72;
			}
			

			.datatable tr.firstrow td {
				border-top: 1px solid #C1DAD7;
			}

			.firstcol {
				border-left: 1px solid #C1DAD7;
				width: 200px;
				font-weight: bold;
			}		

			.alt td {
				background: #F5FAFA;
				color: #797268;
			}


			
			th.spec {
				border-left: 1px solid #C1DAD7;
				border-top: 0;
				background: #fff url(images/bullet1.gif) no-repeat;
				font: bold 10px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
			}
			
			th.specalt {
				border-left: 1px solid #C1DAD7;
				border-top: 0;
				background: #f5fafa url(images/bullet2.gif) no-repeat;
				font: bold 10px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
				color: #797268;
			}

			.emptytable {
				width: 100%;
				padding: 0;
				margin: 0;
				font: 11px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
			}


			.insettable {
				width: 100%;
				padding: 0;
				margin: 0;
				font: 11px "Trebuchet MS", Verdana, Arial, Helvetica, sans-serif;
			}

			.insettable td {
				border-right: 1px solid #000;
				border-bottom: 1px solid #000;
				background: #fff;
				padding: 6px 6px 6px 12px;
				color: #000;
			}
			

			.insettable tr.firstrow td {
				border-top: 1px solid #000;
			}

			.insettable td {
				border-top: 1px solid #000;
			}

			.insettable td {
				border-left: 1px solid #000;

			}		

			.insettable td.firstcol {
				width: 120px;
				font-weight: bold;
			}

			.f {
				vertical-align: top;
			}
	
			.subtableh {
				color: #000;
				margin-bottom: 0px;
				padding-bottom: 0px;
			}



        </style>
    </head>


 <body>
		<h1>Configuration File Parser</h1>
        <div id="TABS">
            <ul>
                <li><a href="#tab_network"><span>Network</span></a></li>
                <li><a href="#tab_system"><span>System</span></a></li>
                <li><a href="#tab_mail"><span>Mail</span></a></li>
				<li><a href="#tab_alerts"><span>Log / Alerts</span></a></li>
				<li><a href="#tab_quarantine"><span>Quarantine</span></a></li>
                <li><a href="#tab_bounce"><span>Bounce Verification</span></a></li>
				<li><a href="#tab_reports"><span>Reports / Tracking</span></a></li>
				<li><a href="#tab_security"><span>Security Management</span></a></li>
				<li onclick="do_print();" class="yellow"><span>Print Page</span></li>



            </ul>

            <div id="tab_network">
				
			

				<br clear="all" />


				<table class="datatable" cellspacing="0" summary="Network Configuration">
				
				<caption>Network Configuration</caption>
	


				  <tr class="firstrow">
				    <td class="firstcol f">HostName</td>
				    <td><xsl:value-of select="config/hostname"/></td>
				  </tr>
	





				  <tr class="alt">
				    <td class="firstcol f">Ports</td>
				    <td>
		
						<table class="insettable">
							<tr>
								<th>Port Name</th>
								<th>MTU</th>
							</tr>

					      <xsl:for-each select="config/ports/port_interface">
							<tr class="firstrow">
								<td class="firstcol">
									<xsl:value-of select="port_name"/> 
									<br />
										<a>
										<xsl:attribute name="href">#int <xsl:value-of select="port_name"/>
										</xsl:attribute>
										Int
										</a>
										--
										<a>
										<xsl:attribute name="href">#eth <xsl:value-of select="port_name"/>
										</xsl:attribute>
										Eth
										</a>

								</td>
								<td><xsl:value-of select="direct/jack_mtu"/></td>
							</tr>
					      </xsl:for-each>



						</table>

					</td>
				  </tr>










 				<tr class="">
				    <td class="firstcol f">Interfaces</td>
				    <td>
		
						

					      <xsl:for-each select="config/interfaces/interface">
									<a>
									<xsl:attribute name="name">int <xsl:value-of select="interface_name"/>
									</xsl:attribute>
									</a>
								<h3 class="subtableh">Interface : <xsl:value-of select="interface_name"/></h3>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">IP Address</td>
										<td><xsl:value-of select="ip"/></td>
									</tr>
									<tr>
										<td class="firstcol">Physical Interface</td>
										<td><xsl:value-of select="phys_interface"/></td>
									</tr>
									<tr>
										<td class="firstcol">Netmask</td>
										<td><xsl:value-of select="netmask"/></td>
									</tr>
									<tr>
										<td class="firstcol">Interface Hostname</td>
										<td><xsl:value-of select="interface_hostname"/></td>
									</tr>
									<tr>
										<td class="firstcol">FTP Port</td>
										<td><xsl:value-of select="ftpd_port"/></td>
									</tr>
									<tr>
										<td class="firstcol">Telnet Port</td>
										<td><xsl:value-of select="telnetd_port"/></td>
									</tr>
									<tr>
										<td class="firstcol">SSHD Port</td>
										<td><xsl:value-of select="sshd_port"/></td>
									</tr>
									<tr>
										<td class="firstcol">HTTPD Port</td>
										<td><xsl:value-of select="httpd_port"/></td>
									</tr>
									<tr>
										<td class="firstcol">HTTPS Redirect</td>
										<td><xsl:value-of select="https_redirect"/></td>
									</tr>
									<tr>
										<td class="firstcol">HTTPS Port</td>
										<td><xsl:value-of select="httpsd_port"/></td>
									</tr>
									<tr>
										<td class="firstcol">euq_httpd_port</td>
										<td><xsl:value-of select="euq_httpd_port"/></td>
									</tr>
									<tr>
										<td class="firstcol">euq_https_redirect</td>
										<td><xsl:value-of select="euq_https_redirect"/></td>
									</tr>
									<tr>
										<td class="firstcol">euq_httpsd_port</td>
										<td><xsl:value-of select="euq_httpsd_port"/></td>
									</tr>
									<tr>
										<td class="firstcol">euq_default_interface</td>
										<td><xsl:value-of select="euq_default_interface"/></td>
									</tr>


								</table>

					      </xsl:for-each>




					</td>
				  </tr>



				  <tr class="alt">
				    <td class="firstcol f">IP Groups</td>
				    <td>No value in sample XML</td>
				  </tr>



				<tr class="">
				    <td class="firstcol f">Ethernet Settings</td>
				    <td>
		
						

					      <xsl:for-each select="config/ethernet_settings/ethernet">
									<a>
									<xsl:attribute name="name">eth <xsl:value-of select="ethernet_interface"/>
									</xsl:attribute>
									</a>
								<h3 class="subtableh">Ethernet : <xsl:value-of select="ethernet_interface"/></h3>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">Media</td>
										<td><xsl:value-of select="media"/></td>
									</tr>
									<tr>
										<td class="firstcol">media_opt</td>
										<td><xsl:value-of select="media_opt"/></td>
									</tr>
									<tr>
										<td class="firstcol">Mac Address</td>
										<td><xsl:value-of select="macaddr"/></td>
									</tr>
									


								</table>

					      </xsl:for-each>




					</td>
				  </tr>




				  <tr class="alt">
				    <td class="firstcol f">DNS</td>
				    <td>


							<h3 class="subtableh">Local DNS</h3>


								<table class="insettable">
											<tr>
											<th>Priority</th>
											<th>Value</th>
											</tr>
											<xsl:for-each select="config/dns/local_dns/dns_ip">
											
												<tr class="firstrow">
													<td><xsl:value-of select="@priority"/></td>
													<td><xsl:value-of select="."/></td>
												</tr>


											</xsl:for-each>
											</table>





							<h3 class="subtableh">Alt DNS</h3>


										<table class="insettable">
											<tr>
											<th>Domain</th>
											<th>NameServer</th>
											<th>IP</th>
											</tr>
											<xsl:for-each select="config/dns/alt_dns/alt_dns_domain">
											
												<tr class="firstrow">
													<td><xsl:value-of select="dns_domain"/></td>
													<td><xsl:value-of select="nameserver/nameserver_name"/></td>
													<td><xsl:value-of select="nameserver/ip"/></td>
												</tr>


											</xsl:for-each>
											</table>



							


						<br />
							<h3 class="subtableh">DNS Settings</h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">dns_ptr_timeout</td>
										<td><xsl:value-of select="config/dns/dns_ptr_timeout"/></td>
									</tr>
									
									<tr>
										<td class="firstcol">dnslist_negative_ttl</td>
										<td><xsl:value-of select="config/dns/dnslist/dnslist_negative_ttl"/></td>
									</tr>
									<tr>
										<td class="firstcol">dnslist_timeout</td>
										<td><xsl:value-of select="config/dns/dnslist/dnslist_timeout"/></td>
									</tr>
									<tr>
										<td class="firstcol">DNS Interface</td>
										<td><xsl:value-of select="config/dns_interface"/></td>
									</tr>

								</table>


					</td>
				  </tr>



				  <tr class="">
				    <td class="firstcol f">Default Gateway</td>
				    <td>
						<xsl:value-of select="config/default_gateway"/>
					</td>
				  </tr>




				  <tr class="alt">
				    <td class="firstcol f">Routes</td>
				    <td>



										<table class="insettable">
											<tr>
											<th>Route Name</th>
											<th>Destination</th>
											<th>Gateway</th>
											</tr>
											<xsl:for-each select="config/routes/route">
											
												<tr class="firstrow">
													<td><xsl:value-of select="route_name"/></td>
													<td><xsl:value-of select="destinatione"/></td>
													<td><xsl:value-of select="gateway"/></td>
												</tr>


											</xsl:for-each>
											</table>



					</td>
				  </tr>



				
				</table>


			</div>











































            <div id="tab_system">



				<br clear="all" />

				<table class="datatable" cellspacing="0" summary="Network Configuration">
				
				<caption>System</caption>
	


	  			<tr class="firstrow">
				    <td class="firstcol f">System Status</td>
				    <td><xsl:value-of select="config/system_state"/></td>
				  </tr>
	

				  <tr class="alt">
				    <td class="firstcol f">Time Server</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">Time Server</td>
										<td><xsl:value-of select="config/ntp/ntp_server"/></td>
									</tr>
									<tr class="firstrow">
										<td class="firstcol">ntp_source_ip_interface</td>
										<td><xsl:value-of select="config/ntp/ntp_source_ip_interface"/></td>
									</tr>

								</table>

					</td>
				  </tr>
	





				  <tr class="">
				    <td class="firstcol f">Certificates</td>
				    <td>
			
								<h3>https_certificate</h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">certificate</td>
										<td><xsl:value-of select="config/https_certificate/certificate"/></td>
									</tr>
									<tr>
										<td class="firstcol">key</td>
										<td><xsl:value-of select="config/https_certificate/key"/></td>
									</tr>

								</table>

					</td>
				  </tr>




				  <tr class="alt">
				    <td class="firstcol f">sshd</td>
				    <td>
			
								
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">ssh_v1_enabled</td>
										<td><xsl:value-of select="config/sshd/ssh_v1_enabled"/></td>
									</tr>

								</table>

					</td>
				  </tr>



				  <tr class="">
				    <td class="firstcol f">Upgrade Info</td>
				    <td>
			
								
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">upgrade_source_ip_interface</td>
										<td><xsl:value-of select="config/upgrade_source_ip_interface"/></td>
									</tr>
									<tr>
										<td class="firstcol">upgrade_port</td>
										<td><xsl:value-of select="config/upgrade_port"/></td>
									</tr>
									<tr>
										<td class="firstcol">upgrade_server_type</td>
										<td><xsl:value-of select="config/upgrade_server_type"/></td>
									</tr>
									<tr>
										<td class="firstcol">local_upgrade_server_url</td>
										<td><xsl:value-of select="config/local_upgrade_server_url"/></td>
									</tr>
									<tr>
										<td class="firstcol">upgrade_proxy_url</td>
										<td><xsl:value-of select="config/upgrade_proxy_url"/></td>
									</tr>
								</table>

					</td>
				  </tr>



 				  <tr class="alt">
				    <td class="firstcol f">Users</td>
				    <td>




											<table class="insettable">
											<tr>
											<th>Username</th>
											<th>Fullname</th>
											<th>Group</th>
											<th>Password</th>
											<th>Public Key</th>
											</tr>
											<xsl:for-each select="config/users/user">
											
												<tr class="firstrow">
													<td><xsl:value-of select="username"/></td>
													<td><xsl:value-of select="fullname"/></td>
													<td><xsl:value-of select="group"/></td>
													<td><xsl:value-of select="enc_password"/></td>
													<td>
														<xsl:for-each select="authorized_keys/public_key">
															Pub Key: <strong>TRIM FUNCTION NEEDED</strong><br />
														</xsl:for-each>
													</td>
												</tr>


											</xsl:for-each>
											</table>





                     </td>
				   </tr>



			


				  <tr class="">
				    <td class="firstcol f">core_watch_enabled</td>
				    <td><xsl:value-of select="config/core_watch_enabled"/></td>
				  </tr>


				  <tr class="alt">
				    <td class="firstcol f">timezone</td>
				    <td><xsl:value-of select="config/timezone"/></td>
				  </tr>


				  <tr class="">
				    <td class="firstcol f">Proxy</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">use_proxy</td>
										<td><xsl:value-of select="config/use_proxy"/></td>
									</tr>
									<tr>
										<td class="firstcol">use_https_proxy</td>
										<td><xsl:value-of select="config/use_https_proxy"/></td>
									</tr>
									<tr>
										<td class="firstcol">proxy_server</td>
										<td><xsl:value-of select="config/proxy_server"/></td>
									</tr>
									<tr>
										<td class="firstcol">https_proxy_server</td>
										<td><xsl:value-of select="config/https_proxy_server"/></td>
									</tr>
									<tr>
										<td class="firstcol">update_interval</td>
										<td><xsl:value-of select="config/update_interval"/></td>
									</tr>
									<tr>
										<td class="firstcol">base_url</td>
										<td><xsl:value-of select="config/base_url"/></td>
									</tr>
									<tr>
										<td class="firstcol">server_type</td>
										<td><xsl:value-of select="config/server_type"/></td>
									</tr>
								</table>

					</td>
				  </tr>


				</table>

            </div>





























            <div id="tab_mail">




				<br clear="all" />

				<table class="datatable" cellspacing="0" summary="Mail Configuration">
				
				<caption>Mail</caption>
	


				  <tr class="firstrow">
				    <td class="firstcol f">global_max listener_concurrency</td>
				    <td><xsl:value-of select="config/global_max_listener_concurrency"/></td>
				  </tr>
				  <tr class="alt">
				    <td class="firstcol f">global_max header_lines</td>
				    <td><xsl:value-of select="config/global_max_header_lines"/></td>
				  </tr>
				  <tr class="">
				    <td class="firstcol f">global_injection control_period</td>
				    <td><xsl:value-of select="config/global_injection_control_period"/></td>
				  </tr>
				  <tr class="alt">
				    <td class="firstcol f">global_inbound conversation_timeout</td>
				    <td><xsl:value-of select="config/global_inbound_conversation_timeout"/></td>
				  </tr>
				  <tr class="">
				    <td class="firstcol f">global_inbound connection_timeout</td>
				    <td><xsl:value-of select="config/global_inbound_connection_timeout"/></td>
				  </tr>
				  <tr class="alt">
				    <td class="firstcol f">global_inbound conversation_timeout</td>
				    <td><xsl:value-of select="config/global_inbound_conversation_timeout"/></td>
				  </tr>
				  <tr class="">
				    <td class="firstcol f">global_stamp received_with_vg</td>
				    <td><xsl:value-of select="config/global_stamp_received_with_vg"/></td>
				  </tr>


				  <tr class="alt">
				    <td class="firstcol f">Tarpit</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">global_enable_tarpit</td>
										<td><xsl:value-of select="config/global_enable_tarpit"/></td>
									</tr>
									<tr>
										<td class="">global_memory_tarpit_start</td>
										<td><xsl:value-of select="config/global_memory_tarpit_start"/></td>
									</tr>
									<tr>
										<td class="">global_memory_tarpit_halt</td>
										<td><xsl:value-of select="config/global_memory_tarpit_halt"/></td>
									</tr>
									<tr>
										<td class="">global_tarpit_suspend_listeners</td>
										<td><xsl:value-of select="config/global_tarpit_suspend_listeners"/></td>
									</tr>
									<tr>
										<td class="">global_tarpit_monitor_work_queue</td>
										<td><xsl:value-of select="config/global_tarpit_monitor_work_queue"/></td>
									</tr>
									<tr>
										<td class="">global_tarpit_work_queue_suspend</td>
										<td><xsl:value-of select="config/global_tarpit_work_queue_suspend"/></td>
									</tr>
									<tr>
										<td class="">global_tarpit_work_queue_resume</td>
										<td><xsl:value-of select="config/global_tarpit_work_queue_resume"/></td>
									</tr>
								</table>

					</td>
				  </tr>


				  <tr class="">
				    <td class="firstcol f">LDAP</td>
				    <td>
								<h3 class="subtableh">LDAP info</h3>
							    <table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">ldap_interface</td>
										<td><xsl:value-of select="config/ldap/ldap_interface"/></td>
									</tr>
									<tr>
										<td class="">ldap_silent_group_failures</td>
										<td><xsl:value-of select="config/ldap/ldap_silent_group_failures"/></td>
									</tr>
								</table>
			
								<h3 class="subtableh">LDAP Servers</h3>
								
											<table class="insettable">
											<tr>
											<th>Name</th>
											<th>Port</th>
											<th>Hostname</th>
											<th>User</th>
											<th>Pass</th>
											<th>base</th>
											</tr>
											<tr>
											<th>authtype</th>
											<th>use_ssl</th>
											<th>compat</th>
											<th>max_conn</th>
											<th colspan="2">conn_behavior</th>
											</tr>
											
											<xsl:for-each select="config/ldap/ldap_server">
												<tr>
													<td colspan="6" style="border: 0px;"><br /></td>
												</tr>
												<tr class="firstrow">
													<td style="font-weight: bold; background-color: #eeff00"><xsl:value-of select="ldap_server_name"/></td>
													<td><xsl:value-of select="ldap_server_port"/></td>
													<td><xsl:value-of select="ldap_server_hostname"/></td>
													<td><xsl:value-of select="ldap_server_user"/></td>
													<td><xsl:value-of select="ldap_server_pass"/></td>
													<td><xsl:value-of select="ldap_server_base"/></td>
												</tr>
												<tr class="firstrow">
													<td><xsl:value-of select="ldap_server_authtype"/></td>
													<td><xsl:value-of select="ldap_server_use_ssl"/></td>
													<td><strong>??</strong> <xsl:value-of select="ldap_server_compat"/></td>
													<td><xsl:value-of select="ldap_server_max_connections"/></td>
													<td colspan="2"><xsl:value-of select="ldap_server_connection_behavior"/></td>
												</tr>
												

											</xsl:for-each>
											</table>




										<h3 class="subtableh">LDAP Queries</h3>
								
											<table class="insettable">
											<tr>
												<th>Name</th>
												<th>Server</th>
												<th>Type</th>
												<th>TTL</th>
												<th>Cache Size</th>
											</tr>
											<tr>
												<th colspan="3" width="50%">Query</th>
												<th colspan="2">Extra</th>
											</tr>
											
											<xsl:for-each select="config/ldap/ldap_query">
												<tr>
													<td colspan="5" style="border: 0px;"><br /></td>
												</tr>
												<tr class="firstrow">
													<td style="font-weight: bold; background-color: #eeff00;"><xsl:value-of select="ldap_query_name"/></td>
													<td><xsl:value-of select="ldap_query_server"/></td>
													<td><xsl:value-of select="ldap_query_type"/></td>
													<td><xsl:value-of select="ldap_query_ttl"/></td>
													<td><xsl:value-of select="ldap_query_cache_size"/></td>
												</tr>
												<tr class="firstrow">
													<td colspan="3"><xsl:value-of select="ldap_query_query"/></td>
													<td colspan="2">
														<table class="insettable">
															<xsl:for-each select="ldap_query_extra_data">
															<tr>
																<td class="firstcol"><xsl:value-of select="ldap_query_extra_data_key"/></td>
																<td><xsl:value-of select="ldap_query_extra_data_value"/></td>
															</tr>
															</xsl:for-each>
														</table>
														
													</td>
												</tr>
												

											</xsl:for-each>
											</table>


								<h3 class="subtableh">LDAP Certificate</h3>
								  <table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">certificate</td>
										<td><xsl:value-of select="config/ldap_certificate/certificate"/></td>
									</tr>
									<tr>
										<td class="">ldap certificate key</td>
										<td><xsl:value-of select="config/ldap_certificate/key"/></td>
									</tr>
								</table>	



					</td>
				  </tr>





				  <tr class="alt">
				    <td class="firstcol f">Bounce</td>
				    <td>
								<h3 class="subtableh">Bounce info</h3>
							    <table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">global_bounce_all_down_host</td>
										<td><xsl:value-of select="config/global_bounce_all_down_host"/></td>
									</tr>
								</table>
			
								<h3 class="subtableh">Bounce Profiles</h3>
								
											<table class="insettable">
											<tr>
											<th>Name</th>
											<th>Max Retries</th>
											<th>Max Queue Lifetime</th>
											<th>Initial Retry</th>
											<th>Max Retry</th>
											<th>Send Bounces</th>
											</tr>
											<tr>
											<th>Send Warnings</th>
											<th>Send Warnings Count</th>
											<th>Send Warnings Interval</th>
											<th>use DNS bounce format</th>
											<th colspan="2">alternate_bounce_address</th>
											</tr>
											
											<xsl:for-each select="config/bounce_profiles/bounce_profile">
												<tr>
													<td colspan="6" style="border: 0px;"><br /></td>
												</tr>
												<tr class="firstrow">
													<td style="font-weight: bold; background-color: #eeff00"><xsl:value-of select="bounce_profile_name"/></td>
													<td><xsl:value-of select="max_retries"/></td>
													<td><xsl:value-of select="max_queue_lifetime"/></td>
													<td><xsl:value-of select="initial_retry"/></td>
													<td><xsl:value-of select="max_retry_time"/></td>
													<td><xsl:value-of select="send_bounces"/></td>
												</tr>
												<tr class="firstrow">
													<td><xsl:value-of select="send_warnings"/></td>
													<td><xsl:value-of select="send_warnings_count"/></td>
													<td><xsl:value-of select="send_warnings_interval"/></td>
													<td><xsl:value-of select="use_dsn_bounce_format"/></td>
													<td colspan="2"><xsl:value-of select="alternate_bounce_address"/></td>
												</tr>
												

											</xsl:for-each>
											</table>






					</td>
				  </tr>






				  <tr class="">
				    <td class="firstcol f">Listeners</td>
				    <td>
											
								
								
								       <div id="listenercontainer">
							            <ul id="navlist">
											<xsl:for-each select="config/listeners/listener">
											<xsl:variable name="cur" select='position()' />
							                <li>
													<a>
													<xsl:attribute name="href">#list_<xsl:value-of select="$cur"/>
													</xsl:attribute>
													<span><xsl:value-of select="listener_name"/> - (<xsl:value-of select="type"/>)</span>
													</a>

											</li>
											</xsl:for-each>
							            </ul>
							

										
											<xsl:for-each select="config/listeners/listener">
											<xsl:variable name="cur" select='position()' />
							                	
													<div>
													<xsl:attribute name="id">list_<xsl:value-of select="$cur"/>
													</xsl:attribute>

														
										
										
			 													<div>
																	<xsl:attribute name="id">list_container_<xsl:value-of select="$cur"/>
																	</xsl:attribute>
										           
																	<ul id="navlist">
																		<li>
																				<a>
																				<xsl:attribute name="href">#listgeneral_<xsl:value-of select="$cur"/>
																				</xsl:attribute>
																				<span>General</span>
																				</a>
																		</li>
																		<li>
																				<a>
																				<xsl:attribute name="href">#listhat_<xsl:value-of select="$cur"/>
																				</xsl:attribute>
																				<span>Hat</span>
																				</a>
												
																		</li>
																		<li>
																				<a>
																				<xsl:attribute name="href">#listrat_<xsl:value-of select="$cur"/>
																				</xsl:attribute>
																				<span>Rat</span>
																				</a>
												
																		</li>
																		<li>
																				<a>
																				<xsl:attribute name="href">#listdomain_<xsl:value-of select="$cur"/>
																				</xsl:attribute>
																				<span>DomainMap</span>
																				</a>
												
																		</li>
																		<li>
																				<a>
																				<xsl:attribute name="href">#listldap_<xsl:value-of select="$cur"/>
																				</xsl:attribute>
																				<span>LDAP</span>
																				</a>
												
																		</li>
																		<li>
																				<a>
																				<xsl:attribute name="href">#listaddress_<xsl:value-of select="$cur"/>
																				</xsl:attribute>
																				<span>AddressParser</span>
																				</a>
												
																		</li>
																		
														            </ul>
											
		
																	<div>
																		<xsl:attribute name="id">listgeneral_<xsl:value-of select="$cur"/>
																		</xsl:attribute>
		
		
																		<table class="insettable">
																			<tr class="firstrow">
																				<td class="firstcol">listener_name</td>
																				<td><xsl:value-of select="listener_name"/></td>
																			</tr>
																			<tr class="">
																				<td class="firstcol">protocol</td>
																				<td><xsl:value-of select="protocol"/></td>
																			</tr>
																			<tr class="">
																				<td class="firstcol">port</td>
																				<td><xsl:value-of select="port"/></td>
																			</tr>
																			<tr class="">
																				<td class="firstcol">listen_queue_size</td>
																				<td><xsl:value-of select="listen_queue_size"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">type</td>
																				<td><xsl:value-of select="type"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">default_domain</td>
																				<td><xsl:value-of select="default_domain"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">max_concurrency</td>
																				<td><xsl:value-of select="max_concurrency"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">smtpauth_enabled</td>
																				<td><xsl:value-of select="smtpauth_enabled"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">smtpauth_profile_name</td>
																				<td><xsl:value-of select="smtpauth_profile_name"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">SenderBase_timeout</td>
																				<td><xsl:value-of select="SenderBase_timeout"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">bounce_profile_name</td>
																				<td><xsl:value-of select="bounce_profile_name"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">enable_received_header</td>
																				<td><xsl:value-of select="enable_received_header"/></td>
																			</tr>
																			<tr class="">
																				<td class="type">clean_smtp</td>
																				<td><xsl:value-of select="clean_smtp"/></td>
																			</tr>
																		</table>
																	</div>
						
																	<div>
																		<xsl:attribute name="id">listhat_<xsl:value-of select="$cur"/>
																		</xsl:attribute>
										


																		<h3 class="">Hat Defaults</h3>
																					<table class="insettable">
																						<tr class="firstrow">
																							<td class="firstcol">hat_default max_concurrency</td>
																							<td><xsl:value-of select="hat_default_max_concurrency"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default max_message_size</td>
																							<td><xsl:value-of select="hat_default_max_message_size"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default max_msgs per_session</td>
																							<td><xsl:value-of select="hat_default_max_msgs_per_session"/></td>
																						</tr>	
																						<tr class="">
																							<td class="firstcol">hat_default max_rcpts per_msg</td>
																							<td><xsl:value-of select="hat_default_max_rcpts_per_msg"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default smtp_banner_code</td>
																							<td><xsl:value-of select="hat_default_smtp_banner_code"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default smtp_banner_text</td>
																							<td><xsl:value-of select="hat_default_smtp_banner_text"/></td>
																						</tr>																					
																						<tr class="">
																							<td class="firstcol">hat_default reject_banner_code</td>
																							<td><xsl:value-of select="hat_default_reject_banner_code"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default reject_banner_text</td>
																							<td><xsl:value-of select="hat_default_reject_banner_text"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default use_override_hostname</td>
																							<td><xsl:value-of select="hat_default_use_override_hostname"/></td>
																						</tr>																								

																						<tr class="">
																							<td class="firstcol">hat_default override_hostname</td>
																							<td><xsl:value-of select="hat_default_override_hostname"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default tls</td>
																							<td><xsl:value-of select="hat_default_tls"/></td>
																						</tr>																					
																						<tr class="">
																							<td class="firstcol">hat_default accept_untagged_bounces</td>
																							<td><xsl:value-of select="hat_default_accept_untagged_bounces"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default smtpauth_allow</td>
																							<td><xsl:value-of select="hat_default_smtpauth_allow"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">hat_default smtpauth_requiretls</td>
																							<td><xsl:value-of select="hat_default_smtpauth_requiretls"/></td>
																						</tr>	



																					</table>






																		<table class="insettable">
																			<tr class="firstrow">
																				
																				<td width="100%">
																					<pre>
																				 <xsl:call-template name="replaceBR">
																				      <xsl:with-param name="text" select="hat"/>
																				      <xsl:with-param name="replace" select="'&#10;'"/>
																				    
																				    </xsl:call-template>
																				
																					</pre>
																				</td>
																			</tr>
																		</table>																
																	</div>

																	<div>
																		<xsl:attribute name="id">listrat_<xsl:value-of select="$cur"/>
																		</xsl:attribute>
										
																		<table class="insettable">
																			<tr class="firstrow">
																				
																				<td width="100%">

																					<table class="insettable">
																						
																						<tr>
																						<th>Addresses</th>
																						<th>Access</th>
																						<th>Params</th>
																						</tr>

																						<xsl:for-each select="rat/rat_entry">
																						<tr class="firstrow">
																							
																							<td>
																								<xsl:for-each select="rat_address">
																								<xsl:value-of select="."/><br />
																								</xsl:for-each>
																							</td>
																						
																							<td><xsl:value-of select="access"/></td>
																						
																							<td>
																								<strong>smtp_response_text</strong>: <xsl:value-of select="rat_params/smtp_response_text"/><br />
																								<strong>smtp_response_code</strong>: <xsl:value-of select="rat_params/smtp_response_code"/><br />
																								<strong>bypass_ldap_accept</strong>: <xsl:value-of select="rat_params/bypass_ldap_accept"/><br />
																								<strong>bypass_receiving_control</strong>: <xsl:value-of select="rat_params/bypass_receiving_control"/><br />

																							</td>
																						</tr>
																						
																					</xsl:for-each>

																					</table>
																				</td>
																			</tr>
																		</table>																
																	</div>
		


																	<div>
																		<xsl:attribute name="id">listdomain_<xsl:value-of select="$cur"/>
																		</xsl:attribute>
										
																		<table class="insettable">
																			<tr class="firstrow">
																				
																				<td width="100%">

																					<table class="insettable">
																						
																						<tr>
																						<th width="50%">Original</th>
																						<th>New</th>
																						
																						</tr>

																						<xsl:for-each select="domain_map_table/domain_map_table_entry">
																						<tr class="firstrow">
																							
																							<td>
																								
																								<xsl:value-of select="orig_domain"/>
																							</td>
																						
																							<td><xsl:value-of select="new_domain"/></td>
																						
																							
																						</tr>
																						
																					</xsl:for-each>

																					</table>
																				</td>
																			</tr>
																		</table>																
																	</div>
		




																	<div>
																		<xsl:attribute name="id">listldap_<xsl:value-of select="$cur"/>
																		</xsl:attribute>
										
																		<table class="insettable">
																			<tr class="firstrow">
																				
																				<td width="100%">

																					<table class="insettable">
																						<tr class="firstrow">
																							<td class="firstcol">masquerade_query</td>
																							<td><xsl:value-of select="listener_ldap/masquerade_query"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">rat_action</td>
																							<td><xsl:value-of select="listener_ldap/rat_action"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">accept_action</td>
																							<td><xsl:value-of select="listener_ldap/accept_action"/></td>
																						</tr>	
																						<tr class="">
																							<td class="firstcol">smtp_timeout_action</td>
																							<td><xsl:value-of select="listener_ldap/smtp_accept/smtp_timeout_action"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">smtp_timeout_code</td>
																							<td><xsl:value-of select="listener_ldap/smtp_accept/smtp_timeout_code"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">smtp_timeout_message</td>
																							<td><xsl:value-of select="listener_ldap/smtp_accept/smtp_timeout_message"/></td>
																						</tr>																					
																						<tr class="">
																							<td class="firstcol">smtp_dhap_action</td>
																							<td><xsl:value-of select="listener_ldap/smtp_accept/smtp_dhap_action"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">smtp_dhap_code</td>
																							<td><xsl:value-of select="listener_ldap/smtp_accept/smtp_dhap_code"/></td>
																						</tr>
																						<tr class="">
																							<td class="firstcol">smtp_dhap_message</td>
																							<td><xsl:value-of select="listener_ldap/smtp_accept/smtp_dhap_message"/></td>
																						</tr>																								

																					</table>
																				</td>
																			</tr>
																		</table>																
																	</div>




																	<div>
																		<xsl:attribute name="id">listaddress_<xsl:value-of select="$cur"/>
																		</xsl:attribute>
										
																		<table class="insettable">
																			<tr class="firstrow">
																				
																				<td width="100%">

																					<table class="insettable">
																						
																						<tr>
																						<th width="50%">Original</th>
																						<th>New</th>
																						
																						</tr>

																						<xsl:for-each select="domain_map_table/domain_map_table_entry">
																						<tr class="firstrow">
																							
																							<td>
																								
																								<xsl:value-of select="orig_domain"/>
																							</td>
																						
																							<td><xsl:value-of select="new_domain"/></td>
																						
																							
																						</tr>
																						
																					</xsl:for-each>

																					</table>
																				</td>
																			</tr>
																		</table>																
																	</div>




																</div>


							

													</div>
											
											</xsl:for-each>

										</div>



					</td>
				  </tr>







			</table>




            </div>








































			 <div id="tab_alerts">
               

				<br clear="all" />

				<table class="datatable" cellspacing="0" summary="Network Configuration">
				
				<caption>Logs and Alerts</caption>
	


				  <tr class="firstrow">
				    <td class="firstcol f">hostkeys</td>
				    <td>

							
		
								<table class="insettable">
									<xsl:for-each select="config/hostkeys/hostkey">
									<tr class="firstrow">
										<td class="firstcol">hostkey</td>
										<td style="color: red;"><strong>TRIM FUNCTION NEEDED</strong></td>
									</tr>
							      	</xsl:for-each>									
									
								</table>



					</td>
				  </tr>
	

				  <tr class="alt">
				    <td class="firstcol f">log_subscriptions</td>
				    <td>
							
							<xsl:for-each select="config/log_subscriptions/log_text">



							
								<h3 class="subtableh">Text: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									<tr>
										<td class="firstcol">module</td>
										<td><xsl:value-of select="module"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>
									<tr>
										<td class="firstcol">log_level</td>
										<td><xsl:value-of select="log_level"/></td>
									</tr>
								</table>
							<br />




							</xsl:for-each>	




							<xsl:for-each select="config/log_subscriptions/log_status">



							
								<h3 class="subtableh">Status: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>

								</table>
							<br />




							</xsl:for-each>	




							<xsl:for-each select="config/log_subscriptions/log_bounces">



							
								<h3 class="subtableh">Bounce: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>

									<tr>
										<td class="firstcol">bytes_to_record</td>
										<td><xsl:value-of select="bytes_to_record"/></td>
									</tr>
								</table>
							<br />




							</xsl:for-each>	

	





								<xsl:for-each select="config/log_subscriptions/log_antispam">



							
								<h3 class="subtableh">AntiSpam Log: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>
									<tr>
										<td class="firstcol">log_level</td>
										<td><xsl:value-of select="log_level"/></td>
									</tr>



								</table>
							<br />




							</xsl:for-each>	


							<xsl:for-each select="config/log_subscriptions/log_antispam_archive">



							
								<h3 class="subtableh">AntiSpam Archive: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>

								</table>
							<br />




							</xsl:for-each>	



							<xsl:for-each select="config/log_subscriptions/log_cli">



							
								<h3 class="subtableh">CLI Log: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>

								</table>
							<br />




							</xsl:for-each>	






							<xsl:for-each select="config/log_subscriptions/log_scanning">



							
								<h3 class="subtableh">Scanning: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>
									<tr>
										<td class="firstcol">log_level</td>
										<td><xsl:value-of select="log_level"/></td>
									</tr>
								</table>
							<br />




							</xsl:for-each>	








							<xsl:for-each select="config/log_subscriptions/log_antivirus">



							
								<h3 class="subtableh">AntiVirus: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>
									<tr>
										<td class="firstcol">log_level</td>
										<td><xsl:value-of select="log_level"/></td>
									</tr>
								</table>
							<br />




							</xsl:for-each>	




							<xsl:for-each select="config/log_subscriptions/log_euq">



							
								<h3 class="subtableh">EUQ: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>
									<tr>
										<td class="firstcol">log_level</td>
										<td><xsl:value-of select="log_level"/></td>
									</tr>
								</table>
							<br />




							</xsl:for-each>	






							<xsl:for-each select="config/log_subscriptions/log_euqgui">



							
								<h3 class="subtableh">EUQ GUI: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>
									<tr>
										<td class="firstcol">log_level</td>
										<td><xsl:value-of select="log_level"/></td>
									</tr>
								</table>
							<br />




							</xsl:for-each>	






							<xsl:for-each select="config/log_subscriptions/log_reportd">



							
								<h3 class="subtableh">Reportd: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>
									<tr>
										<td class="firstcol">log_level</td>
										<td><xsl:value-of select="log_level"/></td>
									</tr>
								</table>
							<br />




							</xsl:for-each>	



							<xsl:for-each select="config/log_subscriptions/log_reportqueryd">



							
								<h3 class="subtableh">Reportqueryd: <xsl:value-of select="name"/></h3>
								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">name</td>
										<td><xsl:value-of select="name"/></td>
									</tr>
									
									
									<tr>
										<td class="firstcol">retrieval filename</td>
										<td><xsl:value-of select="retrieval/ftp_poll/filename"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rolloversize</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rolloversize"/></td>
									</tr>
									<tr>
										<td class="firstcol">retrieval rollover_max_files</td>
										<td><xsl:value-of select="retrieval/ftp_poll/rollover_max_files"/></td>
									</tr>
									<tr>
										<td class="firstcol">log_level</td>
										<td><xsl:value-of select="log_level"/></td>
									</tr>
								</table>
							<br />




							</xsl:for-each>	


					</td>
				  </tr>


				  <tr class="">
				    <td class="firstcol f">log_system measurements_frequency</td>
				    <td><xsl:value-of select="config/log_system_measurements_frequency"/></td>
				  </tr>
	

				  <tr class="alt">
				    <td class="firstcol f">log_message_id</td>
				    <td><xsl:value-of select="config/log_message_id"/></td>
				  </tr>



				  <tr class="">
				    <td class="firstcol f">log_orig_subj</td>
				    <td><xsl:value-of select="config/log_orig_subj"/></td>
				  </tr>

	

				  <tr class="alt">
				    <td class="firstcol f">log_remote response</td>
				    <td><xsl:value-of select="config/log_remote_response"/></td>
				  </tr>





				  <tr class="">
				    <td class="firstcol f">Email Alert Configruation</td>
				    <td>

 							 <table class="insettable">

									
									<tr class="firstrow">
										<td class="firstcol">Email From:</td>
										<td><xsl:value-of select="config/alert_email_config/alert_from_email_address"/></td>
									</tr>

									
								</table>
							

							<xsl:for-each select="config/alert_email_config/alert_class">

								<h3 class="subtableh">Class Name: <xsl:value-of select="@name"/></h3>
								
								  <table class="insettable">

									<xsl:for-each select="alert_severity">

									
									<tr class="firstrow">
										<td class="firstcol"><xsl:value-of select="@name"/></td>
										<td>
											<xsl:for-each select="email_address">
											<xsl:value-of select="."/>
											<br />
											</xsl:for-each>
										</td>
									</tr>
									
									</xsl:for-each>

									
								</table>
							<br />


							</xsl:for-each>



					</td>
				  </tr>





			</table>

            </div>

			 <div id="tab_quarantine">
               


				<br clear="all" />

				<table class="datatable" cellspacing="0" summary="Quarantine">
				
				<caption>Quarantine</caption>
	


				  <tr class="firstrow">
				    <td class="firstcol f">euq_on_box</td>
				    <td><xsl:value-of select="config/euq/system_euq/euq_on_box"/></td>
				  </tr>



				  <tr class="alt">
				    <td class="firstcol f">euq_dedicated_appliances</td>
				    <td>


										<xsl:for-each select="config/euq/euq_mail/euq_dedicated_appliances/euq_dedicated_appliance">

												<table class="insettable">
												<tr class="firstrow">
													<td>Appliance</td>
													<td><xsl:value-of select="."/></td>
												</tr>
												</table>
												<hr />

											</xsl:for-each>

					</td>
				  </tr>


				  <tr class="">
				    <td class="firstcol f">euq_to_corpus</td>
				    <td><xsl:value-of select="config/euq/euq_mail/euq_to_corpus"/></td>
				  </tr>

				  <tr class="alt">
				    <td class="firstcol f">euq_to_corpus_addr</td>
				    <td><xsl:value-of select="config/euq/euq_mail/euq_to_corpus_addr"/></td>
				  </tr>


 			  	  <tr class="">
				    <td class="firstcol f">euq_server</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">euq_db_pct_full_alert</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_db_pct_full_alert"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_db_total_size</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_db_total_size"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_disable_notification</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_disable_notification"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_disable_time_expire</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_disable_time_expire"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_message_ttl</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_message_ttl"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_notification_frequency</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_notification_frequency"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_language</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_language"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_out_of_limit_action</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_out_of_limit_action"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_run_cleanup_script_at</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_run_cleanup_script_at"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_source_appliances</td>
										<td>

										<xsl:for-each select="config/euq/euq_server/euq_source_appliances/euq_source_appliance">

												<table class="insettable">
												<tr class="firstrow">
													<td>Source Appliance</td>
													<td><xsl:value-of select="."/></td>
												</tr>
												</table>
												<hr />

											</xsl:for-each>

										</td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_enable_end_user_access</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_enable_end_user_access"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_hide_message_bodies</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_hide_message_bodies"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_release_host</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_release_host"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_release_port</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_release_port"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_alt_release_host</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_alt_release_host"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_alt_release_port</td>
										<td><xsl:value-of select="config/euq/euq_server/euq_alt_release_port"/></td>
									</tr>

								</table>

					</td>
				  </tr>



	

 			  	  <tr class="alt">
				    <td class="firstcol f">euq_gui</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">euq_gui_custom_logo</td>
										<td><xsl:value-of select="config/euq/euq_gui/euq_gui_custom_logo"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_gui_custom_login_message</td>
										<td><xsl:value-of select="config/euq/euq_gui/euq_gui_custom_login_message"/></td>
									</tr>
								</table>

					</td>
				  </tr>

 			  	  <tr class="">
				    <td class="firstcol f">euq access</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">euq_method</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_method"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_auth_server</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_auth_server"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_auth_port</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_auth_port"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_transport</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_transport"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_test_user</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_test_user"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_ldap_server_type</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_ldap_server_type"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_ldap_wins_name</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_ldap_wins_name"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_ldap_dn</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_ldap_credentials/euq_ldap_dn"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_ldap_password</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_ldap_credentials/euq_ldap_password"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_ldap_query_base</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_ldap_query_base"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_ldap_query_filter</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_ldap_query_filter"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_ldap_alias_email_attr</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_ldap_alias_email_attr"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_ldap_email_attr</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_ldap_email_attr"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_default_domain</td>
										<td><xsl:value-of select="config/euq/euq_access/euq_default_domain"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_adminusers</td>
										<td>

											<xsl:for-each select="config/euq/euq_access/euq_adminusers/username">
											
												<strong>User:</strong> <xsl:value-of select="."/><br />

											</xsl:for-each>

										</td>
									</tr>



								</table>

					</td>
				  </tr>



 			  	  <tr class="alt">
				    <td class="firstcol f">euq database</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">euq_db_api</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_api"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_db_host</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_host"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_db_port</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_port"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_db_user</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_user"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_db_name</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_name"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">EUQ DB Pools</td>
										<td>

											<table class="insettable">
											<tr>
											<th>name</th>
											<th>connections</th>
											</tr>
											<xsl:for-each select="config/euq/euq_db/euq_db_pools/euq_db_pool">
											
												<tr class="firstrow">
													<td><xsl:value-of select="@name"/></td>
													<td><xsl:value-of select="@total_connections"/></td>
												</tr>


											</xsl:for-each>
											</table>

										</td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_db_total_connections</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_total_connections"/></td>
									</tr>									
									<tr class="">
										<td class="firstcol">euq_db_body_location</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_body_location"/></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_db_check_delay</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_check_delay"/></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_db_free_inode_threshold</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_free_inode_threshold"/></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_db_percent_db_clear_for_inodes</td>
										<td><xsl:value-of select="config/euq/euq_db/euq_db_percent_db_clear_for_inodes"/></td>
									</tr>	

								</table>

					</td>
				  </tr>





 			  	  <tr class="">
				    <td class="firstcol f">euq notification</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">euq_notify_format</td>
										<td><xsl:value-of select="config/euq/euq_notify/euq_notify_format"/></td>
									</tr>
									<tr class="">
										<td class="firstcol">euq_notify_bounce_address</td>
										<td><xsl:value-of select="config/euq/euq_notify/euq_notify_bounce_address"/></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_notify_from_address</td>
										<td><xsl:value-of select="config/euq/euq_notify/euq_notify_from_address"/></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_notify_log_msg_sent</td>
										<td><xsl:value-of select="config/euq/euq_notify/euq_notify_log_msg_sent"/></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_notify_method</td>
										<td><xsl:value-of select="config/euq/euq_notify/euq_notify_method"/></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_notify_subject</td>
										<td><xsl:value-of select="config/euq/euq_notify/euq_notify_subject"/></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_notify_template</td>
										<td><xsl:value-of select="config/euq/euq_notify/euq_notify_template" disable-output-escaping="yes" /></td>
									</tr>		
									<tr class="">
										<td class="firstcol">euq_notify_enable_consolidation</td>
										<td><xsl:value-of select="config/euq/euq_notify/euq_notify_enable_consolidation"/></td>
									</tr>	




							
								</table>

					</td>
				  </tr>





				</table>


            </div>



























			 <div id="tab_bounce">


				<br clear="all" />

				<table class="datatable" cellspacing="0" summary="Bounce Configuration">
				
				<caption>Bounce Configuration</caption>
	


				  <tr class="firstrow">
				    <td class="firstcol f">bounce_verification</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">bounce_verification_reject_behavior_type</td>
										<td><xsl:value-of select="config/bounce_verification/bounce_verification_reject_behavior/bounce_verification_reject_behavior_type"/></td>
									</tr>
									<tr class="firstrow">
										<td class="firstcol">bounce_verification_secret</td>
										<td><xsl:value-of select="config/bounce_verification/bounce_verification_secret"/></td>
									</tr>
									<tr class="firstrow">
										<td class="firstcol">bounce_verification_smart_exceptions</td>
										<td><xsl:value-of select="config/bounce_verification/bounce_verification_smart_exceptions"/></td>
									</tr>

								</table>

					</td>
				  </tr>
	









				</table>


            </div>

























			 <div id="tab_reports">
               
				<br clear="all" />

				<table class="datatable" cellspacing="0" summary="Reporting and Tracking">
				
				<caption>Reporting and Tracking</caption>
	


				  <tr class="firstrow">
				    <td class="firstcol f">Reporting Enabled</td>
					<td><xsl:value-of select="config/reporting/reporting_enabled"/></td>
				  </tr>
	
				  <tr class="alt">
				    <td class="firstcol f">Reporting Slave Enabled</td>
					<td><xsl:value-of select="config/reporting/reporting_slave/reporting_slave_enabled"/></td>
				  </tr>

				  <tr class="">
				    <td class="firstcol f">Reporting Database Size</td>
					<td><xsl:value-of select="config/reporting/reportd_db/db_environment_actual_size"/></td>
				  </tr>

				  <tr class="alt">
				    <td class="firstcol f">Reporting Second Level Domains</td>
					<td><xsl:value-of select="config/reporting/reporting_custom_second_level_domains"/></td>
				  </tr>

				  <tr class="">
				    <td class="firstcol f">Reporting Rollup Filters</td>
					<td>

										<xsl:for-each select="config/reporting/reporting_enabled_rollup_filters/reporting_rollup_filter_name">

												<table class="insettable">
												<tr class="firstrow">
													<td>Name</td>
													<td><xsl:value-of select="."/></td>
												</tr>
												</table>
												<hr />

											</xsl:for-each>



					</td>
				  </tr>


				  <tr class="alt">
				    <td class="firstcol f">periodic_reports</td>
					<td>

										<xsl:for-each select="config/reporting/periodic_reports/periodic_report">

												<h3 class="subtableh"><xsl:value-of select="periodic_report_key"/></h3>
												<table class="insettable">

													<tr class="firstrow">
														<td class="firscol" width="200">periodic_report_title</td>
														<td><xsl:value-of select="periodic_report_title"/></td>
													</tr>

													<tr class="">
														<td>periodic_report_def_id</td>
														<td><xsl:value-of select="periodic_report_def_id"/></td>
													</tr>
													<tr class="">
														<td>periodic_report_archive</td>
														<td><xsl:value-of select="periodic_report_archive"/></td>
													</tr>

													<tr class="">
														<td>periodic_report_creation_timestamp</td>
														<td><xsl:value-of select="periodic_report_creation_timestamp"/></td>
													</tr>



													<tr class="">
														<td>E-mail Recipients</td>
														<td>

														<xsl:for-each select="periodic_report_recipients/periodic_report_recipient">
																
															<xsl:value-of select="."/>
															<br />
			
			
														</xsl:for-each>

													</td>
													</tr>

													<tr class="">
														<td>periodic_report_options</td>
														<td>
																<table class="insettable">
																<tr class="firstrow">
																	<td>periodic_report_days_include</td>
																	<td><xsl:value-of select="periodic_report_options/periodic_report_days_include"/></td>
																</tr>
																<tr class="">
																	<td>periodic_report_rows</td>
																	<td><xsl:value-of select="periodic_report_options/periodic_report_rows"/></td>
																</tr>
																<tr class="">
																	<td>periodic_report_filter</td>
																	<td><xsl:value-of select="periodic_report_options/periodic_report_filter"/></td>
																</tr>
																<tr class="">
																	<td>periodic_report_duration</td>
																	<td><xsl:value-of select="periodic_report_options/periodic_report_duration"/></td>
																</tr>
																</table>

																


														</td>
													</tr>


													<tr class="">
														<td>Periodic Report Period</td>
														<td>
																<table class="insettable">
																
																<tr>
																	<th>Weekday</th>
																	<th>Day</th>
																	<th>Hour</th>
																	<th>Minute</th>
																	<th>Second</th>
																</tr>

																<tr class="firstrow">
																	<td><xsl:value-of select="periodic_report_weekdays/periodic_report_weekday"/></td>
																	<td><xsl:value-of select="periodic_report_days/periodic_report_day"/></td>
																	<td><xsl:value-of select="periodic_report_hours/periodic_report_hour"/></td>
																	<td><xsl:value-of select="periodic_report_minutes/periodic_report_minute"/></td>
																	<td><xsl:value-of select="periodic_report_seconds/periodic_report_second"/></td>

																</tr>

																</table>

																


														</td>
													</tr>


												</table>
												<hr />

											</xsl:for-each>



					</td>
				  </tr>


	 			 <tr class="">
				    <td class="firstcol f">Tracking</td>
					<td>

										<table class="insettable">
												<tr class="firstrow">
													<td class="firscol" width="200">Centralized Tracking Enabled</td>
													<td><xsl:value-of select="config/tracking/tracking_centralized/tracking_centralized_enabled"/></td>
												</tr>
												<tr class="">
													<td>Global Tracking Enabled</td>
													<td><xsl:value-of select="config/tracking/tracking_global/tracking_global_enabled"/></td>
												</tr>
												<tr class="">
													<td>Global Tracking Max DB Size</td>
													<td><xsl:value-of select="config/tracking/tracking_global/tracking_global_max_db_size"/></td>
												</tr>
												<tr class="">
													<td>Hermes Tracking Enabled</td>
													<td><xsl:value-of select="config/tracking/tracking_hermes/tracking_hermes_logging_enabled"/></td>
												</tr>
												<tr class="">
													<td>Hermes Tracking Connections</td>
													<td><xsl:value-of select="config/tracking/tracking_hermes/tracking_hermes_track_connections"/></td>
												</tr>
												<tr class="">
													<td>Loal Tracking Directory</td>
													<td><xsl:value-of select="config/tracking/tracking_local/tracking_local_local_directory"/></td>
												</tr>
												<tr class="">
													<td>Loal Tracking Export Directory</td>
													<td><xsl:value-of select="config/tracking/tracking_local/tracking_local_export_directory"/></td>
												</tr>
												</table>
	


					</td>
				  </tr>



				</table>


            </div>
































			 <div id="tab_security">




				<br clear="all" />

				<table class="datatable" cellspacing="0" summary="Security Management">
				
				<caption>Security Management</caption>
	


				  <tr class="firstrow">
				    <td class="firstcol f">smad</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">Global smad</td>
										<td><xsl:value-of select="config/smad/smad_global/smad_global_hosts"/></td>
									</tr>
								</table>

					</td>
				  </tr>
	


				  <tr class="alt">
				    <td class="firstcol f">SSL Properties</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">ssl_inbound_method</td>
										<td><xsl:value-of select="config/ssl/ssl_inbound_method"/></td>
									</tr>
									<tr>
										<td class="firstcol">ssl_inbound_ciphers</td>
										<td><xsl:value-of select="config/ssl/ssl_inbound_ciphers"/></td>
									</tr>
									<tr>
										<td class="firstcol">ssl_outbound_method</td>
										<td><xsl:value-of select="config/ssl/ssl_outbound_method"/></td>
									</tr>
									<tr>
										<td class="firstcol">ssl_outbound_ciphers</td>
										<td><xsl:value-of select="config/ssl/ssl_outbound_ciphers"/></td>
									</tr>
								</table>

					</td>
				  </tr>
	

				  <tr class="">
				    <td class="firstcol f">Encryption Properties</td>
				    <td>

								<table class="insettable">
									<tr class="firstrow">
										<td class="firstcol">encryption_enabled</td>
										<td><xsl:value-of select="config/encryption/encryption_enabled"/></td>
									</tr>
									<tr>
										<td>encryption_profiles</td>
										<td>
										
											<xsl:for-each select="config/encryption/encryption_profiles/encryption_profile">

												<table class="insettable">
												<tr class="firstrow">
													<td>Name</td>
													<td><xsl:value-of select="encryption_profile_name"/></td>
												</tr>
												<tr class="">
													<td>Type</td>
													<td><xsl:value-of select="encryption_type"/></td>
												</tr>
												<tr class="">
													<td>External URL</td>
													<td><xsl:value-of select="encryption_external_url"/></td>
												</tr>
												<tr class="">
													<td>Return Receipt</td>
													<td><xsl:value-of select="encryption_return_receipt"/></td>
												</tr>
												<tr class="">
													<td>Sensitivity</td>
													<td><xsl:value-of select="encryption_sensitivty"/></td>
												</tr>
												<tr class="">
													<td>Use Proxy?</td>
													<td><xsl:value-of select="encryption_use_proxy"/></td>
												</tr>
												<tr class="">
													<td>encryption_html_text_resource</td>
													<td><xsl:value-of select="encryption_html_text_resource"/></td>
												</tr>
												<tr class="">
													<td>encryption_plain_text_resource</td>
													<td><xsl:value-of select="encryption_plain_text_resource"/></td>
												</tr>
												<tr class="">
													<td>encryption_algorithm</td>
													<td><xsl:value-of select="encryption_algorithm"/></td>
												</tr>
												<tr class="">
													<td>encryption_applet</td>
													<td><xsl:value-of select="encryption_applet"/></td>
												</tr>
												<tr class="">
													<td>encryption_reply_all</td>
													<td><xsl:value-of select="encryption_reply_all"/></td>
												</tr>
												<tr class="">
													<td>encryption_forward</td>
													<td><xsl:value-of select="encryption_forward"/></td>
												</tr>
												<tr class="">
													<td>encryption_logo_url</td>
													<td><xsl:value-of select="encryption_logo_url"/></td>
												</tr>


											</table>
											</xsl:for-each>
											

										</td>
									</tr>

									<tr>
										<td>encryption_proxy</td>
										<td>

											<table class="insettable">
												<tr class="firstrow">
													<td>encryption_proxy_type</td>
													<td><xsl:value-of select="config/encryption/encryption_proxy/encryption_proxy_type"/></td>
												</tr>
												<tr class="">
													<td>encryption_proxy_port</td>
													<td><xsl:value-of select="config/encryption/encryption_proxy/encryption_proxy_port"/></td>
												</tr>
												<tr class="">
													<td>encryption_proxy_hostname</td>
													<td><xsl:value-of select="config/encryption/encryption_proxy/encryption_proxy_hostname"/></td>
												</tr>
												<tr class="">
													<td>encryption_proxy_user</td>
													<td><xsl:value-of select="config/encryption/encryption_proxy/encryption_proxy_user"/></td>
												</tr>
												<tr class="">
													<td>encryption_proxy_password</td>
													<td><xsl:value-of select="config/encryption/encryption_proxy/encryption_proxy_password"/></td>
												</tr>


											</table>

										</td>
									</tr>

									<tr>
										<td>encryption_mime_map</td>
										<td>

										<table class="insettable">
											<tr>
											<th>Domain</th>
											<th>Type</th>
											</tr>
											<xsl:for-each select="config/encryption/encryption_mime_map/encryption_mime_map_entry">

											
												<tr class="firstrow">
													<td><xsl:value-of select="encryption_mime_map_domain"/></td>
													<td><xsl:value-of select="encryption_mime_map_type"/></td>
												</tr>


											</xsl:for-each>
											</table>
											

										</td>
									</tr>
								</table>

					</td>
				  </tr>




				</table>



            </div>

























			 <div id="tab_print">
                <p></p>
            </div>






		<!-- end of tabs -->
        </div>

</body>
</html>

</xsl:template>












<xsl:template name="replaceBR">
   <xsl:param name="text"/>
   <xsl:param name="replace" />

   <xsl:choose>
   <xsl:when test="contains($text, $replace)">
      <xsl:value-of select="substring-before($text, $replace)"/>
      <br />
      <xsl:call-template name="replaceBR">
         <xsl:with-param name="text" select="substring-after($text, $replace)" />
         <xsl:with-param name="replace" select="$replace" />
      </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
      <xsl:value-of select="$text"/>
   </xsl:otherwise>
   </xsl:choose>

</xsl:template>


<xsl:template name="replace-text">
   <xsl:param name="text"/>
   <xsl:param name="replace" />
   <xsl:param name="by"  />

   <xsl:choose>
   <xsl:when test="contains($text, $replace)">
      <xsl:value-of select="substring-before($text, $replace)"/>
      <xsl:value-of select="$by" disable-output-escaping="yes"/>
      <xsl:call-template name="replace-text">
         <xsl:with-param name="text" select="substring-after($text, $replace)" />
         <xsl:with-param name="replace" select="$replace" />
         <xsl:with-param name="by" select="$by" />
      </xsl:call-template>
   </xsl:when>
   <xsl:otherwise>
      <xsl:value-of select="$text"/>
   </xsl:otherwise>
   </xsl:choose>

</xsl:template>


</xsl:stylesheet>
