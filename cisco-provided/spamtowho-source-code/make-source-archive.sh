#!/bin/sh

mkdir spamtowho
cp *.pl spamtowho/
cp *.pm spamtowho/
cp *.js spamtowho/
cp *.sh spamtowho/
cp Changelog.txt spamtowho/
cp NOTES spamtowho/
cp Search.README spamtowho/
version=`./spamtowho.pl -v | cut -d' ' -f3`
tar -cvf spamtowho-source-$version.tar spamtowho
gzip spamtowho-source-$version.tar
rm -rf spamtowho/
ls -la spamtowho-source-$version.*

