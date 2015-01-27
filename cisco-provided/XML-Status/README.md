# README for IronPort XML Status monitoring.

## Description

This set of programs provides a basic capability of querying and reporting on operation parameters of an IronPort MTA via the appliance's published XML status page. Based on user 'subscriptions,' email alerts will be sent when operational parameters exceed specified values.

Operation is split into two distinct operations: 'retrieve' which uses an HTTP GET operation to save the xml status page locally; and 'process' which parses the subscription file and the XML status page and determines if alert conditions are indicated. Upon alert conditions 'process' connects to the SMTP server to deliver the alert messages.

## Requirements

Running these programs requires a server running Windows 2000/XP or a UNIX system capable of running Perl scripts. This server must have HTTP access to the IronPort appliance and either local or remote access to an SMTP server to deliver alerts.

## Usage

First, edit the file "config.txt" to specify basic operation including URL of the XML status page (which will be of the form http://ironport.company.com/xml/status), username / password for access, name or IP of an SMTP server (which could be the IronPort appliance), and filename of the locally saved status file (default is 'status.xml' which should be fine).

Secondly, edit the file "subscr.txt" to edit or create alert subscriptions.

The format of these files is documented in the files themselves. Lines beginning with # are treated as comments and ignored by the system. These files are expected to be in the same directory as the programs themselves.

Running the system requires a scheduler service such as cron on UNIX or Scheduled Tasks under windows. Both retrieve and process should be run, in that order, as often as every minute. The batch file "monitor.bat" is provided as a convenience for windows users; on UNIX systems the command "./retrieve.pl ; ./process.pl" can be used.


## Notes

	- HTTP is supported; HTTPS is not (yet)
	- Running the retrieve process more often than once per minute can adversely affect the performance of an IronPort appliance under heavy load
