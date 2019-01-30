#!/bin/bash
#
# Info: Build RHV-H ISO after modifications are made
# Author: Jason Woods <jwoods@redhat.com>
# Created: 2018-12-14
# This script has no warranty implied or otherwise.

# where to find/put stuff
BASEDIR="/u/Documents/RHV-H_custom"
BUILDDIR="BUILD"
OUTISO="RHVH-4.2-custom.x86_64.iso"

OUTDIR="${BASEDIR}/${BUILDDIR}"
OUTPUT="${BASEDIR}/${OUTISO}"

iso_name () {
  grep "LABEL=" BUILD/isolinux/isolinux.cfg | head -n1 | \
    sed 's/:/#/;' | \
    cut -f2 -d# | \
    cut -f1 -d' ' | \
    sed 's/LABEL=//;s/\\x20/ /;'
}

main () {
  ISONAME="$(iso_name)"
  cd "${BASEDIR}"
  echo "#-# Generating ISO image ..."
  genisoimage \
    -o "${OUTPUT}" -joliet-long -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
    -boot-info-table -eltorito-alt-boot \
    -e images/efiboot.img -no-emul-boot -R -J -v -T \
    -input-charset utf-8 \
    -V "${ISONAME}" -A "${ISONAME}" \
    "${OUTDIR}" \
    2>&1
  if [ $? = 0 ] ; then
    echo "#-# Making ISO UEFI bootable ..."
    isohybrid -uefi "${OUTPUT}" 2>&1
    echo "#-# Adding MD5 to ISO ..."
    implantisomd5 "${OUTPUT}" 2>&1
  else
    echo
    echo "  ERROR, failed to build ISO."
    echo
  fi
}

main | tee build.out

