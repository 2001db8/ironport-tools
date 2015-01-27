#!/bin/sh

mkdir spamtowho
cp spamtowho.exe spamtowho/
cp *.js spamtowho/
cp Changelog.txt spamtowho/
cp NOTES spamtowho/
version=`./spamtowho.pl -v | cut -d' ' -f3`
tar -cvf spamtowho-windows-$version.tar spamtowho
gzip spamtowho-windows-$version.tar
rm -rf spamtowho/
ls -la spamtowho-windows-$version.*

