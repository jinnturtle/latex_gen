#!/bin/bash

#==============================================================================#
#==============================   latex_gen.sh   ==============================#
#==============================================================================#
# This script acts as a wrapper around a LaTeX compiler, simplifying and       #
# automating some LaTeX workflow elements.                                     #
#------------------------------------------------------------------------------#
# Currently only supporting pdftex with .pdf output, but it should not take    #
# too much work to add some other outputs and compilers if needed.             #
#==============================================================================#

version_maj=2
version_min=1
version_fix=2

# TODO - add a flag for destination of output file

function run_help () {
    echo "USAGE:"
    echo -e "\t$0 [flags]"
    echo "FLAGS:"
    echo -e "\t-d: remove auxilary compilation data after compile"
    echo -e "\t-h: display help"
    echo -e "\t-i: input file (mandatory)"
    echo -e "\t-m: move auxilary compilation data to separate folder after compile"
    echo -e "\t-o: output file path/name (not implemented yet)"
    echo -e "\t-v: print version of this program"
}

function print_ver () {
    echo "version: ${version_maj}.${version_min}.${version_fix}"
}

function rm_generated_files () {
    cd $in_filedir

    local filename_nosuf=$(basename "${in_filename}" .tex)
    rm -fv "$filename_nosuf.aux"
    rm -fv "$filename_nosuf.pyg"
    rm -fv "$filename_nosuf.out"
    rm -fv "$filename_nosuf.toc"
    rm -fv "$filename_nosuf.log"
    rm -rvf "_minted-$filename_nosuf"

    cd --
}

# cannot use --output-dir=<my_dir>, because some packages don't support this
# e.g. minted
function mv_generated_files () {
    cd $in_filedir

    local filename_nosuf=$(basename "${in_filename}" .tex)
    local aux_dirname="${filename_nosuf}_aux_build_files"
    rm -rf "${aux_dirname}"
    mkdir -p "${aux_dirname}"
    mv -fv "$filename_nosuf.aux" \
       "$filename_nosuf.pyg" \
       "$filename_nosuf.out" \
       "$filename_nosuf.toc" \
       "$filename_nosuf.log" \
       "$aux_dirname"
    mv -fv "_minted-$filename_nosuf" \
       "$aux_dirname/"

    cd --
}


# flags used to determine what to do with auxilliary files after compile
aux_handling=""
aux_move="m"
aux_del="d"

in_filepath=""
out_filepath_override="" # override default output location

# process args
args=($@)
for i in ${!args[@]}; do
    if [ "${args[$i]}" == "-h" ]; then
        run_help
        exit 0
    elif [ "${args[$i]}" == "-i" ]; then
        in_filepath=$(realpath ${args[$((i+1))]})
    elif [ "${args[$i]}" == "-m" ]; then
        aux_handling="$aux_move"
    elif [ "${args[$i]}" == "-d" ]; then
        aux_handling="$aux_del"
    elif [ "${args[$i]}" == "-v" ]; then
        print_ver
        exit 0
    elif [ "${args[$i]}" == "-o" ]; then
        out_filepath_override="$(realpath ${args[$((i+1))]})"
    fi
done

# can't have both move and delete set
if [ "$flag_move" != "" ] && [ "$flag_del" != "" ]; then
    echo "setting both 'move' and 'delete' flags at that same time is not allowed"
    exit 1
fi

#latex has to be run several times (up to 3) to compile well (e.g. when there
#   is a multi-page table of contents)
runs_needed=3
runs_done=0

in_filedir=$(dirname "${in_filepath}")
in_filename=$(basename "${in_filepath}")

if [ "$in_filepath" == "" ]; then
    echo "no file specified"
    exit 1
fi

# debug stuff
# echo "h: $flag_help m: $flag_move d: $flag_del"
# echo "aux_han: $aux_handling"
# echo "i: $in_filepath i_f: $in_filename i_d: $in_filedir"
# echo "stopping due to testing"
# exit

#remove auxilary latex files before we start, leftover *.aux has caused
#   compilation problems before
rm_generated_files

# compile the file specified in $in_filename
# (running several passes because of how latex compiler works)
while [ $runs_done -lt $runs_needed ]; do
    # some latex modules are capricious and want the latex compiler to be called
    # from the same directory where the source file is
    cd $in_filedir

    echo
    echo "run #$(($runs_done +1))"
    echo

    #latex -shell-escape $in_filename
    pdflatex -shell-escape $in_filename
    if [ $? -ne 0 ]; then
        echo
        echo "there were latex compiler errors, aborting"
        exit 1
    fi
    runs_done=$((++runs_done))

    cd --
done

# decide what to do with auxilliary files if anything
if [ "$aux_handling" == "$aux_move" ]; then
    mv_generated_files
elif [ "$aux_handling" == "$aux_del" ]; then
    rm_generated_files
fi

# move output file if output filepath override is set
if [ "$out_filepath_override" != "" ]; then
    cd $in_filedir

    filename_nosuf=$(basename "${in_filename}" .tex)
    default_outp=$(realpath "$filename_nosuf.pdf")
    mv -v $default_outp $out_filepath_override

    cd --
fi

exit 0

