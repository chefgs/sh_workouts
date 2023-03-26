#!/bin/sh
#######################################################################################
## Script Can be Used to Create TOC reference in README files
## Step1: Create a file contains the Blog/Markdown content with headings starting with #
## Step2: Execute the script with filename as argument
## ./toc-from-markdown.sh <file_name_contains_markdow>
## The console shows the output with TOC formetting
## Just Copy Paste the Content in your README.md file
## This Utility Script Can be Used for Blogging sites which supports MARKDOWN formatting
########################################################################################
blog_filename=$1
grep "#" $blog_filename | tr -d '^#' | sed 's/^ //' | while read line
do
	field2=`echo $line | tr [:upper:] [:lower:] | tr " " "-"`
	echo "- ["$line"]""(#"$field2")"
done
