[ $# == 2 ] || exit 100

for ((i=1; i<=$#; i++))
do
  file=${!i}
  if [[ $file == *.json ]] ; then
    grep -qc PYTHONPATH $file  || exit 101
    grep -qc ofiuco_pip $file  || exit 102
  fi
  if [[ $file == *.zip ]] ; then
    unzip -l $file | grep -qce '.*pip/_internal/main.py$'  || exit 103
  fi
done

exit 0
