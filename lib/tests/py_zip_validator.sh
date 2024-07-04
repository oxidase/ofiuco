[ $# == 2 ] || exit 1

for ((i=1; i<=$#; i++))
do
  file=${!i}
  if [[ $file == *.json ]] ; then
    grep -qc PYTHONPATH $file  || exit 1
    grep -qc ofiuco_pip $file  || exit 1
  fi
  if [[ $file == *.zip ]] ; then
    unzip -l $file | grep -qce '.*_main.*.py$'  || exit 1
  fi
done

exit 0
