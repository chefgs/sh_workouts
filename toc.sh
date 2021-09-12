#!/bin/sh
toc_filename=$1
cat $toc_filename  | while read line
do
	field1=`echo $line | cut -f1 -d"("`
#	echo $field1

	field2=`echo $line | cut -f2 -d"(" | tr [:upper:] [:lower:] | tr " " "-"`
#	echo $field2

echo $field1"("$field2
done
