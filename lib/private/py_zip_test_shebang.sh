[ $# == 1 ] || exit 100

for ((i=1; i<=$#; i++))
do
  file=${!i}
  if [[ $file == *.pyz ]] ; then
    exec $file | grep hello | grep py_zip_test_binary.py || exit 101
  fi
done

exit 0
