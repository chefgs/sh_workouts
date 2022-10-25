#! /bin/bash
echo -n "Enter name of the user: "
read user
c=$(who | grep -ci $user)
if [ $c -gt 0 ]
then
        echo "User is logged in to the system"
else
        echo "User is not logged in to the system"
fi