#!/bin/bash
#
# getGenomeFromEnsembl.sh 
#
# ./getGenomeFromEnsembl.sh -g mus_musculus_aj -n A/J -r 97 -d ./downloads -o ./output -k 4000000
#
# Download genome data (gene model annotations and genome assemblies) from Ensembl
# and import into MGV data files.
# 
# Actions = download, import, or *
# Parts = models, assembly, or *
# 

source utils.sh

ENSEMBL_BASE="rsync://ftp.ensembl.org/ensembl/pub"
ORGANISM=""
NAME=""
TAXONID=""
RELEASE=""
DDIR="./downloads"
ODIR="./output"
DRY_RUN=""
K="4000000"
CHR_REGEX="..?"  # matches chromosomes of one or 2 characters
EXCLUDE_TYPES="biological_region,chromosome,scaffold"

DATATYPE="" # models, assembly. If not specified, run all parts
PHASE="" # download, import. If not specified, run all phases


# ---------------------
usage () {
  echo "Usage: bash ${SCRIPT} [-g organism-path][-n organism-name][-r release][-d downloads-dir][-o output-dir][-D]"
  exit -1
}

# ---------------------
downloadModels () {
  #
  logit "Downloading ${ORGANISM} gene models."
  mkdir -p ${G_DDIR}
  rsync -av --progress ${DRY_RUN} "$GFF_URL" "${GFF_GZ_FILE}"
  checkExit "Failed downloading ${GFF_URL} to ${GFF_GZ_FILE}"
}

# ---------------------
downloadAssembly () {
  #
  logit "Downloading ${ORGANISM} genome assembly."
  mkdir -p ${F_DDIR}
  rsync -av --progress ${DRY_RUN} "$FASTA_URL" "${FASTA_GZ_FILE}"
  checkExit "Failed downloading ${FASTA_URL} to ${FASTA_GZ_FILE}"
}

# ---------------------
importAssembly () {
  logit "Importing ${ORGANISM} genome assembly."
  mkdir -p "${G_ODIR}"
  mkdir -p "${G_ODIR}/sequences"
  if [[ ${DRY_RUN} == "" ]] ; then
    gunzip -c "${FASTA_GZ_FILE}" | python splitFasta.py -c "${CHR_REGEX}" -o ${G_ODIR}/sequences
  fi
}

# ---------------------
importModels () {
  logit "Importing ${ORGANISM} gene models."
  mkdir -p "${G_ODIR}"
  if [[ ${DRY_RUN} == "" ]] ; then
    gunzip -c "${GFF_GZ_FILE}" | \
    python prepEnsemblGff.py -x "${EXCLUDE_TYPES}" -c "${CHR_REGEX}" | \
    python importGff3.py -p ${ORGANISM} -g ${NAME} -x ${TAXONID} -k ${K} -d ${ODIR}
  fi
}

# ---------------------
SCRIPT="$0"
until [ -z "$1" ]  # Until all parameters used up . . .
do
    case "$1" in
    --help|-h)
        # print help and exit
        usage
        ;;
    -d)
        # set the downloads directory
        shift
        DDIR="$1"
        ;;
    -o)
        # set the output directory
        shift
        ODIR="$1"
        ;;
    -g)
        # set the organism path name, eg mus_musculus_dba2j
        shift
        ORGANISM="$1"
        ;;
    -n)
        # set the organism name, eg DBA/2J
        shift
        NAME="$1"
        ;;
    -x)
        # set the taxon id
        shift
        TAXONID="$1"
        ;;
    -r)
        # specify ensembl release number, eg 97
        shift
        RELEASE="$1"
        ;;
    -t)
        # which data type to work on (models, assembly)
        shift
        DATATYPE="$1"
        ;;
    --exclude)
        # which SO types to exclude from GFF3 file
        shift
        EXCLUDE_TYPES="$1"
        ;;
    --chr-regex)
        # which SO types to exclude from GFF3 file
        shift
        CHR_REGEX="$1"
        ;;
    -p)
        # which phase to run (download, import)
        shift
        PHASE="$1"
        ;;
    -D)
        # flag to specify that we're doing a dry run
        DRY_RUN="--dry-run"
        ;;
    *)
        # anything else is an error
        echo "Unrecognized option:" $1
        usage
    esac
    shift
done
#
G_DDIR="${DDIR}"
F_DDIR="${DDIR}"
G_ODIR="${ODIR}/${ORGANISM}"
GFF_URL="${ENSEMBL_BASE}/release-${RELEASE}/gff3/${ORGANISM}/*.${RELEASE}.gff3.gz"
GFF_GZ_FILE="${G_DDIR}/${ORGANISM}.${RELEASE}.gff3.gz"
FASTA_URL="${ENSEMBL_BASE}/release-${RELEASE}/fasta/${ORGANISM}/dna/*.dna.toplevel.fa.gz"
FASTA_GZ_FILE="${F_DDIR}/${ORGANISM}.${RELEASE}.fa.gz"
#
if [[ !(${ORGANISM} && ${RELEASE}) ]] ; then
  die "Please specify both organism and release."
fi
if [[ ! ${NAME} ]] ; then
  NAME="${ORGANISM}"
fi
#
if [[ ${DATATYPE} == "" || ${DATATYPE} == "models" ]] ; then
  if [[ ${PHASE} == "" || ${PHASE} == "download" ]] ; then
    downloadModels
  fi
  if [[ ${PHASE} == "" || ${PHASE} == "import" ]] ; then
    importModels
  fi
fi
#
if [[ ${DATATYPE} == "" || ${DATATYPE} == "assembly" ]] ; then
  if [[ ${PHASE} == "" || ${PHASE} == "download" ]] ; then
    downloadAssembly
  fi
  if [[ ${PHASE} == "" || ${PHASE} == "import" ]] ; then
    importAssembly
  fi
fi
