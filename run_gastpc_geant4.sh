#!/usr/bin/env bash

################################################################################

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

USRDIR='/dune/app/users/jmalbos/ndtf/4RT'
DATADIR='/pnfs/dune/tape_backed/dunepro/mc/neardet/gartpc/ndtf-4rt'
ROCK_LISTFILE="${USRDIR}/rock_${FLAVOUR}.txt"
SCRIPT="${USRDIR}/${FLAVOUR}.${JOB_GROUP}.g4sim.sh"
G4MACRO="${USRDIR}/g4_config.${FLAVOUR}.mac"

############################################################

echo '#!/usr/bin/env bash'                                  >  ${SCRIPT}
echo ''                                                     >> ${SCRIPT}
echo "FLAVOUR=${FLAVOUR}"                                   >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}
echo "JOB_GROUP=${JOB_GROUP}"                               >> ${SCRIPT}
echo 'JOB_NUMBER=$((10#$JOB_GROUP * 1000 + PROCESS))'       >> ${SCRIPT}
echo 'printf -v JOB_NUMBER '\'%05.0f\'' ${JOB_NUMBER}'      >> ${SCRIPT}
echo 'echo "-- Job number: [ ${JOB_NUMBER} ]"'              >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}
echo "DATADIR=${DATADIR}"                                   >> ${SCRIPT}
echo "ROCK_LISTFILE=${USRDIR}/rock_${FLAVOUR}.txt"          >> ${SCRIPT}
echo "G4MACRO=${G4MACRO}"                                   >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}

### Initialize ups and setup required products #################################
echo 'source /grid/fermiapp/products/dune/setup_dune.sh'    >> ${SCRIPT}
echo 'setup gastpc v3_1 -q e10:prof'                        >> ${SCRIPT}
echo 'setup genie_xsec v2_10_6 -q defaultplusccmec'         >> ${SCRIPT}
echo 'setup genie_phyopt v2_10_6 -q dkcharmtau'             >> ${SCRIPT}
echo 'setup ifdhc'                                          >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}

### Input files ################################################################
echo 'GENIEDIR=${DATADIR}/gen/${FLAVOUR}/${JOB_GROUP}'      >> ${SCRIPT}
echo 'GENIEFILE=${FLAVOUR}.${JOB_NUMBER}.ghep.root'         >> ${SCRIPT}
echo 'ifdh cp ${GENIEDIR}/${GENIEFILE} genie.ghep.root'     >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}
echo 'ROCKFILE=`shuf -n 1 ${USRDIR}/${ROCK_LISTFILE}`'      >> ${SCRIPT}
echo 'ifdh cp ${ROCKFILE} rock.ghep.root'                   >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}
echo 'COSMICS=/pnfs/dune/persistent/TaskForce_Flux/cosmics/pass3/gntp.generator-allcosmics.ghep.root' >> ${SCRIPT}
echo 'ifdh cp ${COSMICS} cosmics.ghep.root'                 >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}

### Run Geant4 app #############################################################
echo 'ifdh ${G4MACRO} g4_config.mac'                        >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}
echo 'GasTPCG4Sim \'                                        >> ${SCRIPT}
echo ' -c g4_config.mac \'                                  >> ${SCRIPT}
echo ' -d DUNE -g BEAM_SPILL -n 200 -r ${JOB_NUMBER}'       >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}

### Copy files to dCache #############################################
echo 'ifdh cp output.g4sim.root \'                          >> ${SCRIPT}
echo '${DATADIR}/sim/${FLAVOUR}/${JOB_GROUP}/${FLAVOUR}.${JOB_NUMBER}.g4sim.root' >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}
echo 'rm output.g4sim.root'                                 >> ${SCRIPT}
echo 'rm genie.ghep.root'                                   >> ${SCRIPT}
echo 'rm cosmics.ghep.root'                                 >> ${SCRIPT}
echo 'rm rock.ghep.root'                                    >> ${SCRIPT}
echo 'rm g4_config.mac'                                     >> ${SCRIPT}
echo ''                                                     >> ${SCRIPT}

setup jobsub_client
jobsub_submit \
  --group dune --role=Analysis -N 10 --OS=SL6 --expected-lifetime=8h \
  file://${SCRIPT}
