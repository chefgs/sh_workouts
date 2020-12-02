# Final working sigle line commands and script
string="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla faucibus sagittis diam, id tempor leo auctor id. Fusce varius condimentum congue. Aenean quis dui in justo posuere consequat. Duis orci odio, dignissim ac ultrices id, elementum et nunc. Praesent congue congue justo et aliquam. Donec consectetur ultrices leo, eget rhoncus libero ornare ut. Vivamus et blandit sem. Sed vitae turpis ac nisl semper volutpat a tincidunt mi. In interdum metus a quam scelerisque nec dignissim nisi fringilla. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Phasellus nec augue augue, nec condimentum nulla. Sed in leo ante."

echo $string | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sed '/^$/d' | sort | uniq -c | sort -nr
# cat file.txt | tr -c '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' | sed '/^$/d' | sort | uniq -c | sort -nr

# Where,
# tr -c '[:alnum:]' '\n'		-> Convert the paragraph (all alpha numeric chars) into one column single word per line ('tr [OPTION]... SET1 [SET2]' -c use the complement of SET1)
# tr '[:upper:]' '[:lower:]'	-> Convert upper case letters to lower case letters
# sed '/^$/d'					-> Remove empty newlines
# sort 							-> Sort each line alphabettically
# uniq -c 						-> Count the word occurrances and prefix lines by the number of occurrences
# sort -nr						-> Compare and sort according to string numerical value and print in reverse desc order 

ll | tr -c '[:graph:]' '\n' | sed '/^$/d' | sort | uniq -c | sort -n | grep 

# Where,
# tr -c '[:graph:]' '\n'		-> Convert the paragraph (all printable chars) into one column single word per line ('tr [OPTION]... SET1 [SET2]' -c use the complement of SET1)
# tr '[:upper:]' '[:lower:]'	-> Convert upper case letters to lower case letters
# sed '/^$/d'					-> Remove empty newlines
# sort 							-> Sort each line alphabettically
# uniq -c 						-> Count the word occurrances and prefix lines by the number of occurrences
# sort -nr						-> Compare and sort according to string numerical value and print in reverse desc order 

# ll | tr -c '[:graph:]' '\n' | sed '/^$/d' | sort | uniq -c | sort -n | grep -w '\-rw'
# ll | tr -c '[:graph:]' '\n' | sed '/^$/d' | sort | uniq -c | sort -n | grep 'drw'




