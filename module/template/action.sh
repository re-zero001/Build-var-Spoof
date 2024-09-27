MODPATH="${0%/*}"

# ensure not running in busybox ash standalone shell
set +o standalone
unset ASH_STANDALONE
sh $MODPATH/autopif.sh || exit 1

echo -e "\nDone!"
echo -e "\nClosing dialog in 15 seconds ..."
sleep 15
