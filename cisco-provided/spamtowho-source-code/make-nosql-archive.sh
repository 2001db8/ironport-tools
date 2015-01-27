#!/bin/sh

mkdir spamtowho
cp spamtowho.exe spamtowho/
cp spamtowho-linux spamtowho/
cp *.pl spamtowho/
cp *.pm spamtowho/
cp *.js spamtowho/
cp Changelog.txt spamtowho/
cp NOTES spamtowho/
cp Search.README spamtowho/
version=`./spamtowho.pl -v | cut -d' ' -f3`
tar -cvzf spamtowho$version.tgz spamtowho
rm -rf spamtowho/
ls -la spamtowho$version.tgz

