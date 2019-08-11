#!/bin/bash
#
# getGenome.sh 
#
# Downloads genome data (gene model annotations and genome assemblies) from Ensembl
# for a specified Ensembl release and organism. Imports into MGV data files. 
#
source utils.sh

# ---------------------
usage () {
  echo "Usage: bash ${SCRIPT} [-g organism-path][-n organism-name][-r release][-t PART][-p PHASE]"
  exit -1
}

# ---------------------
downloadModels () {
  #
  logit "Downloading ${ORGANISM} gene models to ${GFF_GZ_FILE}."
  mkdir -p ${DDIR}
  rsync -av --progress ${DRY_RUN} "$GFF_URL" "${GFF_GZ_FILE}"
  checkExit
}

# ---------------------
importModels () {
  logit "Importing ${ORGANISM} gene models to ${ODIR}."
  mkdir -p "${G_ODIR}"
  if [[ ${DRY_RUN} == "" ]] ; then
    gunzip -c "${GFF_GZ_FILE}" | \
    ${PYTHON} prepGff3.py -x "${EXCLUDE_TYPES}" -c "${CHR_REGEX}" ${MODULES} | \
    ${PYTHON} importGff3.py -p ${ORGANISM} -g ${NAME} -x ${TAXONID} -k ${K} -d ${ODIR}
  fi
}

# ---------------------
downloadAssembly () {
  #
  logit "Downloading ${ORGANISM} genome assembly to ${FASTA_GZ_FILE}."
  mkdir -p ${DDIR}
  rsync -av --progress ${DRY_RUN} "$FASTA_URL" "${FASTA_GZ_FILE}"
  checkExit "Failed downloading ${FASTA_URL} to ${FASTA_GZ_FILE}"
}

# ---------------------
importAssembly () {
  logit "Importing ${ORGANISM} genome assembly to ${G_ODIR}/sequences."
  mkdir -p "${G_ODIR}"
  mkdir -p "${G_ODIR}/sequences"
  if [[ ${DRY_RUN} == "" ]] ; then
    gunzip -c "${FASTA_GZ_FILE}" | ${PYTHON} importFasta.py -c "${CHR_REGEX}" -o ${G_ODIR}/sequences
  fi
}

# ---------------------
SCRIPT="$0"
MODULES=""
until [ -z "$1" ]  # Until all parameters used up . . .
do
    case "$1" in
    --help|-h)
        # print help and exit
        usage
        ;;
    -m)
        # set the organism path name, eg mus_musculus_dba2j
        shift
        MODULES="-m $1"
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
        # which chromsomes to process.
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
G_ODIR="${ODIR}/${ORGANISM}"
G_WDIR="${WDIR}/${ORGANISM}"
GFF_GZ_FILE="${DDIR}/${ORGANISM}.${RELEASE}.gff3.gz"
FASTA_URL="${ENSEMBL_BASE}/release-${RELEASE}/fasta/${ORGANISM}/dna/*.dna.toplevel.fa.gz"
FASTA_GZ_FILE="${DDIR}/${ORGANISM}.${RELEASE}.fa.gz"
#
if [[ ${DDIR} == "" ]] ; then
    die "Please specify downloads directory in config.sh (DDIR)."
fi
if [[ ${ODIR} == "" ]] ; then
    die "Please specify output directory in config.sh (ODIR)."
fi
if [[ !(${ORGANISM} && ${RELEASE}) ]] ; then
  die "Please specify both organism and release."
fi
if [[ ! ${NAME} ]] ; then
  NAME="${ORGANISM}"
fi
GFF_URL="${ENSEMBL_BASE}/release-${RELEASE}/gff3/${ORGANISM}/*.${RELEASE}.gff3.gz"
MODULES="-m pg_ensembl,pg_tagEnsemblWithMgi"
DOWNLOADER="rsync"

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
