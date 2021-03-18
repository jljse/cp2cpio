#! /bin/bash

#
#  copy files into cpio.
#    cp2cpio.sh FROM_DIR TO_CPIO
#

arg_from_path=$1
arg_to_path=$2

die() {
    echo $@ >&2
    echo "usage: cp2cpio.sh FROM_DIR TO_CPIO" >&2
    exit 1
}

[ -n "$BASH_VERSION" ] || die "please run on bash"

[ -d "$arg_from_path" ] || die "bad from dir $arg_from_path"
[ -f "$arg_to_path" ] || die "bad to cpio path $arg_to_path"
[[ $arg_to_path =~ .*\.cpio.* ]] || die "bad to cpio path $arg_to_path"

arg_from_path_abs=$(cd $arg_from_path && pwd)
arg_to_path_abs=$(cd $(dirname $arg_to_path) && pwd)/$(basename $arg_to_path)

tmpdir=$(mktemp -d)
trap "echo TRAP EXIT; rm -rf $tmpdir" EXIT


# copy dest cpio to working tmpdir
tmp_arg_dest_path=$tmpdir/$(basename $arg_to_path_abs)
cp $arg_to_path_abs $tmp_arg_dest_path

# gunzip dest file if it's gzip archived
if [[ $tmp_arg_dest_path =~ .*\.gz$ ]]; then
    is_to_path_gzip=true
    gunzip --force --keep $tmp_arg_dest_path
    tmp_cpio_path=${tmp_arg_dest_path%.gz}
else
    is_to_path_gzip=false
    tmp_cpio_path=$tmp_arg_dest_path
fi

# extract cpio with fakeroot
mkdir -p $tmp_cpio_path.extract
cd $tmp_cpio_path.extract
cat $tmp_cpio_path | fakeroot -s $tmp_cpio_path.fakeroot cpio -i -m

# copy with rsync
# (r: recursive, i: show change-summary, p: preserve permissions, t: preserve time)
fakeroot -i $tmp_cpio_path.fakeroot -s $tmp_cpio_path.fakeroot \
    rsync -ript $arg_from_path_abs/ $tmp_cpio_path.extract

# archive to cpio
cd $tmp_cpio_path.extract
find | fakeroot -i $tmp_cpio_path.fakeroot cpio -o -H newc >$tmp_cpio_path.new

# gzip result file if input file was gzip archived
if $is_to_path_gzip; then
    gzip $tmp_cpio_path.new
    resultfile_new=$tmp_cpio_path.new.gz
else
    resultfile_new=$tmp_cpio_path.new
fi

# final result
mv $arg_to_path_abs $arg_to_path_abs.bk
mv $resultfile_new $arg_to_path_abs
