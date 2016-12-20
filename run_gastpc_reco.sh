#!/usr/bin/env bash

print_usage() {
  echo "Usage: `basename ${0}` <mode> <lower_bound> <upper_bound>"
}

ceiling_divide() {
  ceiling_result=$((($1+$2-1)/$2))
  echo $ceiling_result
}


if [[ $# -le 2 ]]; then
  print_usage
  exit 1
fi


############################################################

FLAVOUR=$1
LOWER_BOUND=$2
UPPER_BOUND=$3

if [ "${FLAVOUR}" == "neutrino" ]; then
  NU_EVENTS=125
  GENIE_EVENTS=25474 # 125 times 200 plus 3 sigma
  ROCK_EVENTS=666
  ROCK_LISTFILE="rock_${FLAVOUR}.txt"
elif [ "${FLAVOUR}" == "antineutrino" ]; then
  NU_EVENTS=50
  GENIE_EVENTS=10300 # 50 times 200 plus 3 sigma
  ROCK_EVENTS=448
  ROCK_LISTFILE="rock_${FLAVOUR}.txt"
else
  print_usage
  echo '       <mode>: neutrino | antineutrino'
  exit 1
fi

echo "-- Flavour mode: ${FLAVOUR}"
echo "-- Job number range: [ ${LOWER_BOUND}, ${UPPER_BOUND} ]"

############################################################

USRDIR='/dune/app/users/jmalbos/ndtf/4RT'
OUTDIR='/pnfs/dune/tape_backed/dunepro/mc/neardet/gartpc/ndtf-4rt'
FLUXAPP='copy_dune_ndtf_flux'

############################################################

setup jobsub_client

for i in `seq ${LOWER_BOUND} ${UPPER_BOUND}`; do

  printf -v JOB_NUMBER '%05.0f' ${i}
  JOB_GROUP=${JOB_NUMBER:0:2}

  #echo "-- Job number: ${JOB_NUMBER}"
  #echo "-- Job group: ${JOB_GROUP}"

  # We'll write a script for each job in the range chosen by the user
  SCRIPT=${USRDIR}/${FLAVOUR}.${JOB_NUMBER}.sh

  ### Initialize ups and setup required products #######################
  echo '#!/usr/bin/env bash'                                >  ${SCRIPT}
  echo ''                                                   >> ${SCRIPT}
  echo 'source /grid/fermiapp/products/dune/setup_dune.sh'  >> ${SCRIPT}
  echo 'setup gastpc v2_3 -q e10:prof'                      >> ${SCRIPT}
# echo 'setup genie v2_10_10 -q e10:prof:r6'                >> ${SCRIPT}
  echo 'setup genie_xsec v2_10_6 -q defaultplusccmec'       >> ${SCRIPT}
  echo 'setup genie_phyopt v2_10_6 -q dkcharmtau'           >> ${SCRIPT}
  echo 'setup ifdhc'                                        >> ${SCRIPT}
  echo ''                                                   >> ${SCRIPT}

  ### Copy simulation files ############################################
  echo 'ifdh cp \'                                                                      >> ${SCRIPT}
  echo ' '${OUTDIR}/sim/${FLAVOUR}/${JOB_GROUP}/${FLAVOUR}.${JOB_NUMBER}.g4sim.root' \' >> ${SCRIPT}
  echo ' input.g4sim.root'                                                              >> ${SCRIPT}
  echo ''                                                                               >> ${SCRIPT}

  ### Run pseudo-reconstruction ########################################
  echo 'GasTPCReco '

  ### Copy files to dCache #############################################
  echo 'ifdh cp '${FLAVOUR}.${i}.dst.root' \'                                  >> ${SCRIPT}
  echo ${OUTDIR}/dst/${FLAVOUR}/${JOB_GROUP}/${FLAVOUR}.${JOB_NUMBER}.dst.root >> ${SCRIPT}
  echo ''                                                                      >> ${SCRIPT}
  echo 'rm input.g4sim.root'                                                   >> ${SCRIPT}
  echo 'rm '${FLAVOUR}.${i}.dst.root                                           >> ${SCRIPT}

  jobsub_submit \
   --group dune --role=Analysis -N 1 --OS=SL6 --expected-lifetime=8h \
   file://${SCRIPT}

done
