#/bin/bash

# COLORS
NC='\033[0m'
NREV='\033[27m'
GREEN='\033[0;7;32m'
YELLOW='\033[0;7;33m'
BLUE='\033[0;7;34m'
PURPLE='\033[0;7;35m'

logn() {
	text="$1"
	shift
	echo -e -n "${BLUE} WAIT ${NREV} ${text}${NC}"
	echo "Running ${text} ($@)" >>download.log
}

logx() {
	text="$1"
	shift
	echo -e "${BLUE}${NREV}Running ${text}${NC}"
	echo "Running ${text} ($@)" >>download.log

	"$@" 2>&1 | tee -a download.log

	if [ $? -eq 0 ]; then
		echo -e "${GREEN} DONE ${NREV} ${text}${NC}"
		echo "Completed ${text}" >>download.log
	else
		echo -e "${YELLOW} FAIL ${NREV} ${text}${NC}"
		echo "Failed ${text}" >>download.log
	fi
	echo >>download.log
}

starttime=""

logi() {
	starttime=$(date +%s)
	echo >>download.log
	date >>download.log
	echo -e "${PURPLE} INFO ${NREV} Starting $1${NC}"
	echo "Starting $1" >>download.log
	echo >>download.log
}

logf() {
	endtime=$(date +%s)
	runtime=$((endtime - starttime))
	echo >>download.log
	echo -e "${PURPLE}${NREV}Finished in ${runtime} s${NC}"
	echo "Finished in ${runtime} s" >>download.log
	echo >>download.log
}

usage() {
	echo "usage: test_data.sh [ animal ]"
}

download() {
	wget -nv -O $2 $1
}

check() {
	md5sum --status -c $1
}
ANIMAL_URL="https://raw.githubusercontent.com/KarenWest/FundamentalsOfDataAnalysisInLanguageR/master/AnimalData.csv"
ANIMAL_PATH="etc/AnimalData.csv"
ANIMAL_HASH="etc/AnimalData.md5"

MOVIE_URL="https://github.com/dgraph-io/benchmarks/raw/master/data/1million.rdf.gz"
MOVIE_PATH="etc/1million.rdf.gz"
MOVIE_HASH="etc/1million.md5"

while [ "$1" != "" ]; do
	case $1 in
	animal)
		logx "[1/2] Download AnimalData" download $ANIMAL_URL $ANIMAL_PATH
		logx "[2/2] Check AnimalData" check $ANIMAL_HASH
		exit
		;;
	movie)
		logx "[1/2] Download MovieData" download $MOVIE_URL $MOVIE_PATH

		logx "[2/2] Check MovieData" check $MOVIE_HASH
		exit
		;;
	*)
		usage
		exit 1
		;;
	esac
	shift
done
