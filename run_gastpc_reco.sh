#!/usr/bin/env bash

print_usage() {
  echo "Usage: `basename ${0}` <mode> <job_group>"
}

if [[ $# -le 1 ]]; then
  print_usage
  exit 1
fi

############################################################

FLAVOUR=$1

if ( [ "${FLAVOUR}" == "neutrino" ] || [ "${FLAVOUR}" == "antineutrino" ] )
then
  echo "-- Beam mode: [ ${FLAVOUR} ]"
else
  print_usage
  echo '       <mode>: neutrino | antineutrino'
  exit 1
fi

############################################################

JOB_GROUP=$2
printf -v JOB_GROUP '%02.0f' ${JOB_GROUP} # change to two-digit format
echo "-- Job group: [ ${JOB_GROUP} ]"

############################################################

USER_DIR='/dune/app/users/jmalbos/ndtf/4RT'
INPUT_DIR='/pnfs/dune/tape_backed/dunepro/mc/neardet/gartpc/ndtf-4rt'
OUTPUT_DIR='/pnfs/dune/persistent/TaskForce_AnaTree/hptcpnd/5thrun/dst'
SCRIPT=${USRDIR}/${FLAVOUR}.${JOB_GROUP}.sh

######################################################################

echo '#!/usr/bin/env bash'                                >  ${SCRIPT}
echo ''                                                   >> ${SCRIPT}
echo "USER_DIR=${USER_DIR}"                               >> ${SCRIPT}
echo "INPUT_DIR=${INPUT_DIR}"                             >> ${SCRIPT}
echo "OUTPUT_DIR=${OUTPUT_DIR}"                           >> ${SCRIPT}
echo "FLAVOUR=${FLAVOUR}"                                 >> ${SCRIPT}
echo ''                                                   >> ${SCRIPT}
echo "JOB_GROUP=${JOB_GROUP}"                             >> ${SCRIPT}
echo 'JOB_NUMBER=$((10#$JOB_GROUP * 1000 + PROCESS))'     >> ${SCRIPT}
echo 'printf -v JOB_NUMBER '\'%05.0f\'' ${JOB_NUMBER}'    >> ${SCRIPT}
echo 'echo "-- Job number: [ ${JOB_NUMBER} ]"'            >> ${SCRIPT}
echo ''                                                   >> ${SCRIPT}
echo 'INFILE=${FLAVOUR}.${JOB_NUMBER}.g4sim.root'         >> ${SCRIPT}
echo 'OUTFILE=${FLAVOUR}.${JOB_NUMBER}.dst.root'          >> ${SCRIPT}
echo ''                                                   >> ${SCRIPT}

### Initialize ups and setup required products #######################
echo 'source /grid/fermiapp/products/dune/setup_dune.sh'  >> ${SCRIPT}
echo 'setup gastpc v3_2 -q e10:prof'                      >> ${SCRIPT}
echo 'setup genie_xsec v2_10_6 -q defaultplusccmec'       >> ${SCRIPT}
echo 'setup genie_phyopt v2_10_6 -q dkcharmtau'           >> ${SCRIPT}
echo 'setup ifdhc'                                        >> ${SCRIPT}
echo ''                                                   >> ${SCRIPT}

### Copy input file ##################################################
echo 'ifdh cp \'                                          >> ${SCRIPT}
echo ' ${INPUT_DIR}/${INFILE} \'                          >> ${SCRIPT}
echo ' ${INFILE}'                                         >> ${SCRIPT}
echo ''                                                   >> ${SCRIPT}

### Run pseudo-reconstruction ########################################
echo 'GasTPCPseudoReco \'                                 >> ${SCRIPT}
echo ' -r ${JOB_NUMBER} \'                                >> ${SCRIPT}
echo ' -m '${FLAVOUR}' \'                                 >> ${SCRIPT}
echo ' -i ${INFILE} \'                                    >> ${SCRIPT}
echo ' -o ${OUTFILE}'                                     >> ${SCRIPT}
echo ''                                                   >> ${SCRIPT}

### Copy files to dCache #############################################
echo 'ifdh cp ${OUTFILE} \'                               >> ${SCRIPT}
echo ' ${OUTPUT_DIR}/${FLAVOUR}/${JOB_GROUP}/${OUTFILE}'  >> ${SCRIPT}
echo ''                                                   >> ${SCRIPT}
echo 'rm ${INFILE}'                                       >> ${SCRIPT}
echo 'rm ${OUTFILE}'                                      >> ${SCRIPT}
echo ''                                                   >> ${SCRIPT}

setup jobsub_client
jobsub_submit \
  --group dune --role=Analysis -N 1000 --OS=SL6 --expected-lifetime=8h \
  file://${SCRIPT}
