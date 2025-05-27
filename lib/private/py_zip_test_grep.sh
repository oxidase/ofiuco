shift
zip=$1
shift
unzip -l $zip | grep $*  || exit 1

exit 0
