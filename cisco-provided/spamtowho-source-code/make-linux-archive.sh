#!/bin/sh

mkdir spamtowho
cp spamtowho.linux spamtowho/
cp *.js spamtowho/
cp Changelog.txt spamtowho/
cp NOTES spamtowho/
version=`./spamtowho.pl -v | cut -d' ' -f3`
tar -cvf spamtowho-linux-$version.tar spamtowho
gzip spamtowho-linux-$version.tar
rm -rf spamtowho/
ls -la spamtowho-linux-$version.*

