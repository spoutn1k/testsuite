RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

BRED='\033[1;31m'
BGREEN='\033[1;32m'
BBLUE='\033[1;34m'

NC='\033[0m'

#export TAU_MAKEFILE=shared-clang-pdt
export TAU_MAKEFILE=shared-TEST-clang
#export TAU_OPTIONS='-optCompInst -optVerbose'

export LLVM_DIR=/home/users/fdeny/llvm_build/pluginVersions/plugin-tau-llvm-inuse/install


#which clang
#echo $LLVM_DIR

compiletest() {

    InputFile=$1
    Executable=$2
    SourceList=$3

    OptionalC=${4:-C++}

    Compiler=clang++
    TAUBinary=TAU_Profiling_CXX.so
    
    if [ $OptionalC == "C" ]; then
        Compiler="clang"
        TAUBinary="TAU_Profiling.so"
    fi

    ERRFILE="toto"
    
    echo -e "${BBLUE}Instrumentation${NC}"

    $Compiler -o $Executable -O3 -g -fplugin=${LLVM_DIR}/lib/$TAUBinary -mllvm -tau-input-file=$InputFile -ldl -L${TAU}/lib/$TAU_MAKEFILE -lTAU -Wl,-rpath,${TAU}/lib/$TAU_MAKEFILE $SourceList &> $ERRFILE
    RC=$?
    echo -n "C++ instrumentation"
    if [ $RC != 0 ]; then
        echo -e "                               ${BRED}[FAILED]${NC}"
    else
        echo -e "                               ${BGREEN}[PASSED]${NC}"
    fi
    echo -n "Instrumented functions"
    if [ `grep "Instrument"  $ERRFILE | wc -l` -gt 0 ] ; then
        echo -e "                            ${BGREEN}[PASSED]${NC}"
    else
        echo -e "                            ${BRED}[FAILED]${NC}"
    fi

    rm $ERRFILE
}



# Match a line coming from the input file with a line coming from the source code
# returns 0 in the variable $matched if the lines match, 1 otherwise
# Does not consider wildcards
# $1: function prototype
# $2: line
function matchname(){
    funcproto=$1
    line=$2

    
    # Does it end like a function definition?
    # oddly enough, grep is easier for regex matching here
    f1=`echo $line | grep -E "*\)[[:space:]]*\{[[:space:]]*$" | wc -l`
    f2=`echo $line | grep -E "*\)[[:space:]]*$" | wc -l`
    if [[ $(($f1+$f2)) == 0 ]] ; then
	matched=1
	return
    fi

    # Does it start like a function definition?
    nf=`echo $line | cut -d "(" -f 1 | awk {'print NF'}`
    if [[ ! $nf == 2 ]] ; then
	matched=1
	return
    fi

    # Does the input file provide the returned type (optional)
    # if we have 2 fields before the '(' -> yes, otherwise no
    nf=`echo $funcproto | cut -d "(" -f 1 | awk {'print NF'}`

    if [[ $nf == 2 ]] ; then
	# TODO test this
	# does it return the requested type?
	type1=`echo $line | cut -f 1 -d " "`
	type2=`echo $funcproto | cut -f 1 -d " "`
	if [[ ! $type1 == $type2 ]] ; then
	    matched=1
	    return
	fi
    fi

    # Is this the same function name?
    name1=`echo $line | cut -d '(' -f 1 | awk -F " " {'print $NF'}`
    name2=`echo $funcproto | cut -d '(' -f 1 | awk -F " " {'print $NF'}`
    if [[ ! $name1 == $name2 ]] ; then
	matched=1
	return
    fi

    # Which types do we have between the parenthesis

    linetypes=`echo $line |cut -d "(" -f 2 | cut -d ")" -f 1 | awk -F " " {'for(i = 1 ; i < NF ; i+= 2 ) { printf $i " "} '}`
    prototypes=`echo $funcproto | cut -d "(" -f 2 | cut -d ")" -f 1  | sed 's/,//g'`

    # Same number of arguments?
    n1=`echo $linetypes | awk {'print NF'}`
    n2=`echo $prototypes | awk {'print NF'}`
    if [[ ! $n1 == $n2 ]] ; then
	matched=1
	return
    fi

    # We need this to make lists we can manipulate easily
    OLDIFS=$IFS
    IFS=' '
    lt=($linetypes)
    pt=($prototypes)
    IFS=$OLDIFS

    # Compare these lists term by term
    for i in "${!lt[@]}"; do
	if [[ ! ${pt[i]} == ${lt[i]} ]] ; then
	    matched=1
	    return
	fi
    done

    matched=0
}

runexec (){
    OUTFILE="tata"

    executable=$1
    
    rm profile.*
    echo -e "${BBLUE}Basic instrumentation file - cpp${NC}"
    tau_exec  -T serial,clang ./$executable 256 256 &> $OUTFILE
    RC=$?
    echo -n "Execution of C++ instrumented code"
    if [ $RC != 0 ]; then
        echo -e "                ${BRED}[FAILED]${NC}"
    else
        echo -e "                ${BGREEN}[PASSED]${NC}"
    fi
}

verifytest () {
    inputfile=$1

    OUTFILE="tata"

    fExcluded=`sed '/BEGIN_EXCLUDE_LIST/,/END_EXCLUDE_LIST/{/BEGIN_EXCLUDE_LIST/{h;d};H;/END_EXCLUDE_LIST/{x;/BEGIN_EXCLUDE_LIST/,/END_EXCLUDE_LIST/p}};d' $inputfile |  sed -e 's/BEGIN_EXCLUDE_LIST//' -e 's/END_EXCLUDE_LIST//' -e '/^$/d'`
    fIncluded=`sed '/BEGIN_INCLUDE_LIST/,/END_INCLUDE_LIST/{/BEGIN_INCLUDE_LIST/{h;d};H;/END_INCLUDE_LIST/{x;/BEGIN_INCLUDE_LIST/,/END_INCLUDE_LIST/p}};d' $inputfile |  sed -e 's/BEGIN_INCLUDE_LIST//' -e 's/END_INCLUDE_LIST//'  -e '/^$/d'`
    fExcludedFile=`sed '/BEGIN_FILE_EXCLUDE_LIST/,/END_FILE_EXCLUDE_LIST/{/BEGIN_FILE_EXCLUDE_LIST/{h;d};H;/END_FILE_EXCLUDE_LIST/{x;/BEGIN_FILE_EXCLUDE_LIST/,/END_FILE_EXCLUDE_LIST/p}};d' $inputfile |  sed -e 's/BEGIN_FILE_EXCLUDE_LIST//' -e 's/END_FILE_EXCLUDE_LIST//' -e '/^$/d'`
    fIncludedFile=`sed '/BEGIN_FILE_INCLUDE_LIST/,/END_FILE_INCLUDE_LIST/{/BEGIN_FILE_INCLUDE_LIST/{h;d};H;/END_FILE_INCLUDE_LIST/{x;/BEGIN_FILE_INCLUDE_LIST/,/END_FILE_INCLUDE_LIST/p}};d' $inputfile |  sed -e 's/BEGIN_FILE_INCLUDE_LIST//' -e 's/END_FILE_INCLUDE_LIST//'  -e '/^$/d'`

    fInstrumented=`pprof -l | grep -v "Reading" | grep -v ".TAU application"`

    # There might be spaces in the function names: change the separator
    IFS=$'\n' 

    incorrectInstrumentation=0
    for funcinstru in $fInstrumented; do
        #echo "Checking instrumentation of $line"
        varincluded=1
        varexcluded=1
        varfileincluded=0
        varfileexcluded=1

        # First: check that we actually wanted to instrument the instrumented functions
        # in this example we have no wildcards so the matching is straightforward

        # echo "Instrumented function" $funcinstru

        echo $fIncluded | grep -qFw "$funcinstru"
        varincluded=$?
        echo $fExcluded | grep -qFw "$funcinstru"
        varexcluded=$?
        # Where is it defined? Look into all the source files of this directory (might pass as parameters of the function later if necessary)
        # Matching is not as straightforward as with C.
        #	for file in $(ls  *.{cpp,h}); do
        for file in $(ls  *.cpp); do
            for line in "$(cat $file)"; do
                matchname $funcinstru $line
                if [[ $matched == 0 ]] ; then
                    echo QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQqq
                    # echo "I have found " $funcinstru "in file" $file
                    definition=$file
                    break
                fi
            done
        done
        echo $definition
        echo $fIncludedFile | grep -qFw "$definition"
        varfileincluded=$?
        echo $fExcludedFile | grep -qFw "$definition"
        varfileexcluded=$?

        echo HEEEEEEEEEEEEEEEeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
        # echo "Function " $funcinstru " is defined in file " $definition
        #if [[ $fIncludedFile =~ $definition ]] ; then varfileincluded=0 ; fi # good
        #if [[ $fExcludedFile =~ $definition ]] ; then varfileexcluded=1; fi  # bad

        echo $funcinstru
        echo $varincluded
        echo $varexcluded
        echo $varfileincluded
        echo $varfileexcluded

        if [ $varincluded -eq 0 ] && [ ! $varexcluded -eq 0 ] && [ $varfileincluded -eq 0 ] && [ ! $varfileexcluded -eq 0 ];
        then
            echo null > /dev/null
            echo -e "${BGREEN}Lawfully instrumented${NC}"
        elif [ $varincluded -eq 1 ] && [ ! $varexcluded -eq 0 ] && [ $varfileincluded -eq 0 ] && [ ! $varfileexcluded -eq 0 ];
        then
            ((incorrectInstrumentation=incorrectInstrumentation+1))
            echo -e "${BRED}Wrongfully not instrumented: included and not excluded${NC}"
        elif [ $varincluded -eq 0 ] && [ ! $varexcluded -eq 1 ];
        then
            ((incorrectInstrumentation=incorrectInstrumentation+1))
            echo -e "${BRED}Wrongfully instrumented: excluded${NC}"
        elif [ $varincluded -eq 0 ] && [ $varfileincluded -eq 1 ];
        then
            ((incorrectInstrumentation=incorrectInstrumentation+1))
            echo -e "${BRED}Wrongfully instrumented: source file is not included${NC}"
        elif [ $varincluded -eq 0 ] && [ ! $varfileexcluded -eq 1 ];
        then
            ((incorrectInstrumentation=incorrectInstrumentation+1))
            echo -e "${BRED}Wrongfully instrumented: source file is excluded${NC}"
        elif [ $varincluded -eq 1 ] && ([ ! $varexcluded -eq 1 ] || [ $varfileincluded -eq 1 ] || [ ! $varfileexcluded -eq 1 ]);
        then
            echo null > /dev/null
            echo -e "${BGREEN}Lawfully not instrumented: excluded or not included${NC}"
        else
            echo Uncovered case to implement 
            ((incorrectInstrumentation=incorrectInstrumentation+1))
        fi

    done

    for funcinstru in $fInstrumented; do
        echo "Checking inclusion of $funcinstru"
        varincluded=1
        if echo $funcinstru | grep -qF "TAU";
        then
            continue
        fi
        
        echo $fIncluded | grep -qF "$funcinstru"; # We check if the function was indeed included
        varincluded=$?
        
        if [ $varincluded -gt 0 ];
        then
            ((incorrectInstrumentation=incorrectInstrumentation+1))
            echo -e "${BRED}Wrongfully instrumented: not included${NC}"
        fi
    done

    echo -n "Instrumentation of C++ code"
    if [ $incorrectInstrumentation -eq 0 ]; then
        echo -e "                       ${BGREEN}[PASSED]${NC}"
    else
        echo -e "                       ${BRED}[FAILED]${NC}"
    fi

    rm $OUTFILE
}

runtest(){
   
    InputFile=$1
    Executable=$2

    runexec $Executable
    verifytest $InputFile
}

cevtest() {
    InputFile=$1
    Executable=$2
    SourceList=$3
    OptionalC=${4:-C++}

 

    if [ $# -lt 1 ]; then
        echo "Missing input file: stopping the test"
        exit
    fi

    if [ $(cat $1 | wc -l) -eq 0 ]; then
        echo -e "Input file doesn't exist: stopping the test"
        exit
    else
        echo -e "Input file detected"
    fi


    compiletest "$InputFile" "$Executable" "$SourceList" "$OptionalC"
    runtest "$InputFile" "$Executable"
}
