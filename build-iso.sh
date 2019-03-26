#!/bin/bash
#
# Info: Build RHV-H ISO after modifications are made
# Author: Jason Woods <jwoods@redhat.com>
# Created: 2018-12-14
# This script has no warranty implied or otherwise.
#
# 2019-02-11	jwoods	added function update_efiboot and call to it
# 2019-02-12	jwoods	added function update_from_mods if ISO_MODDIR exists
# 2019-02-14	jwoods	changed variables to start with ISO_
# 2019-02-14	jwoods	added code to read $0.rc file, remove .sh in .rc file name

# where to find/put stuff
ISO_BASEDIR="/u/RHV-H_custom"
ISO_BUILDDIR="BUILD"
ISO_IN="${ISO_BASEDIR}/RHVH-4.2-20190117.0-RHVH-x86_64-dvd1.iso"
ISO_OUT="RHVH-4.2-custom.x86_64.iso"
ISO_MNTDIR="${ISO_BASEDIR}/temp-mnt"
ISO_MODDIR="${ISO_BASEDIR}/modifications"

# these can be left auto-configured, or changed as desired
ISO_OUTDIR="${ISO_BASEDIR}/${ISO_BUILDDIR}"
ISO_OUTPUT="${ISO_BASEDIR}/${ISO_OUT}"

# string to use when outputing a note
ISO_NOTE="#-# "

# if exists and is readable, source .rc file for variables
ISO_RCFILE="$(echo "$0" | sed 's/\.sh$//;').rc"

# name of this program
ISO_PROGNAME="$(basename "${0}")"

case "$(echo "${1}" | sed 's/^-*//;')" in
prep|PREP|p|P)
  # default to prep ISO build files
  ISO_MODE="PREP"
  ;;
build|BUILD|b|B|*)
  # default to build ISO
  ISO_MODE="BUILD"
  ;;
esac

function iso_name () {
  # this needs work
  grep "LABEL=" BUILD/isolinux/isolinux.cfg | head -n1 | \
    sed 's/:/#/;' | \
    cut -f2 -d# | \
    cut -f1 -d' ' | \
    sed 's/LABEL=//;s/\\x20/ /;'
}

function update_from_mods () {
  echo "${ISO_NOTE}Updating ISO files from '${ISO_MODDIR}'..."
  pushd "${ISO_MODDIR}" >/dev/null || {
    echo "  ERROR: unable to change to '${ISO_MODDIR}'"
    return
  }
  find . -type f -exec cp -v "{}" "${ISO_OUTDIR}/{}" \;
  popd >/dev/null
}

function update_efiboot () {
  echo "${ISO_NOTE}Updating EFIBOOT image ..."
  [ ! -d "${ISO_MNTDIR}" ] && mkdir "${ISO_MNTDIR}"
  mount "${ISO_OUTDIR}/images/efiboot.img" "${ISO_MNTDIR}" && {
   cp "${ISO_OUTDIR}/EFI/BOOT/grub.cfg" "${ISO_MNTDIR}/EFI/BOOT/grub.cfg"
  } || {
    echo "  ERROR: unable to mount efiboot.img"
  }
  sleep 1
  umount "${ISO_MNTDIR}" && echo "  SUCCESS"
}

function iso_build () {
  # build ISO from files
  ISO_NAME="$(iso_name)"
  cd "${ISO_BASEDIR}"
  # update ISO files from modifications directory files
  update_from_mods
  # update efiboot image, redirect any errors to stdout
  update_efiboot
  echo "${ISO_NOTE}Generating ISO image ..."
  genisoimage \
    -follow-links \
    -o "${ISO_OUTPUT}" -joliet-long -b "isolinux/isolinux.bin" \
    -c "isolinux/boot.cat" -no-emul-boot -boot-load-size 4 \
    -boot-info-table -eltorito-alt-boot \
    -e "images/efiboot.img" -no-emul-boot -R -J -v -T \
    -input-charset utf-8 \
    -V "${ISO_NAME}" -A "${ISO_NAME}" \
    "${ISO_OUTDIR}"
  if [ $? = 0 ] ; then
    echo "${ISO_NOTE}Making ISO UEFI bootable ..."
    isohybrid -uefi "${ISO_OUTPUT}"
    echo "  EXIT: $?"
    echo "${ISO_NOTE}Adding MD5 to ISO ..."
    implantisomd5 "${ISO_OUTPUT}"
    echo "  EXIT: $?"
  else
    echo
    echo "  ERROR: failed to build ISO."
    echo
  fi
}

function iso_prep () {
  # prep files for building ISO
# TMPTMP
echo "PREPPING!"
}

function main () {
  # report if using a .rc file
  if [ -r "${ISO_RCFILE}" ] ; then
    echo "${ISO_NOTE}Used ISO_RCFILE='${ISO_RCFILE}'"
    source "${ISO_RCFILE}"
  fi
  # run according to BUILD or PREP mode
  case "${ISO_MODE}" in
  PREP)
    iso_prep
  ;;
  BUILD|*)
    iso_build
  ;;
  esac
}

main 2>&1 | tee build.out

