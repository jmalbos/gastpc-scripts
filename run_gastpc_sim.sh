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
  GENIE_EVENTS=31780 # 125 times 250 plus 3 sigma
  ROCK_EVENTS=666
  ROCK_LISTFILE="rock_${FLAVOUR}.txt"
elif [ "${FLAVOUR}" == "antineutrino" ]; then
  NU_EVENTS=50
  GENIE_EVENTS=12835 # 50 times 250 plus 3 sigma
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

#setup jobsub_client

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
  echo 'gastpc v2_3 -q e10:prof'                            >> ${SCRIPT}
# echo 'setup genie v2_10_10 -q e10:prof:r6'                >> ${SCRIPT}
  echo 'setup genie_xsec v2_10_6 -q defaultplusccmec'       >> ${SCRIPT}
  echo 'setup genie_phyopt v2_10_6 -q dkcharmtau'           >> ${SCRIPT}
  echo 'setup ifdhc'                                        >> ${SCRIPT}
  echo ''                                                   >> ${SCRIPT}

  ### Copy flux files ##################################################
  echo 'ifdh cp '${USRDIR}/${FLUXAPP} ${FLUXAPP}            >> ${SCRIPT}
  echo 'chmod +x '${FLUXAPP}                                >> ${SCRIPT}
  echo ${FLUXAPP}' \'                                       >> ${SCRIPT}
  echo ' -o local_flux_files \'                             >> ${SCRIPT}
  echo ' -f '${FLAVOUR}' \'                                 >> ${SCRIPT}
  echo ' -b opt_03 \ '                                      >> ${SCRIPT}
  echo ' --maxmb=60 '                                       >> ${SCRIPT}
  echo ''                                                   >> ${SCRIPT}

  ### Run GENIE ########################################################
  echo 'MSGTHR=${GENIEPHYOPTPATH}/Messenger_production.xml' >> ${SCRIPT}
  echo 'export GXMLPATH='${USRDIR}':${GXMLPATH}'            >> ${SCRIPT}
  echo 'export GNUMIXML=DUNE-NDTF-v01.xml'                  >> ${SCRIPT}
  echo ''                                                   >> ${SCRIPT}
  echo 'gevgen_fnal \'                                      >> ${SCRIPT}
  echo ' -f local_flux_files/gsimple*.root,DUNE-NDTF-01 \'  >> ${SCRIPT}
  echo ' -g '${USRDIR}/'geometry.gdml \'                    >> ${SCRIPT}
  echo ' -m '${USRDIR}/'geometry_mxpl.xml \'                >> ${SCRIPT}
  echo ' -t NEAR_DETECTOR_ENV \'                            >> ${SCRIPT}
  echo ' -L cm \'                                           >> ${SCRIPT}
  echo ' -n '${GENIE_EVENTS}' \'                            >> ${SCRIPT}
  echo ' --seed '${i}' \'                                   >> ${SCRIPT}
  echo ' -r '${i}' \'                                       >> ${SCRIPT}
  echo ' -o '${FLAVOUR}' \'                                 >> ${SCRIPT}
  echo ' --message-thresholds ${MSGTHR} \'                  >> ${SCRIPT}
  echo ' --event-record-print-level 0 \'                    >> ${SCRIPT}
  echo ' --cross-sections ${GENIEXSECFILE} \'               >> ${SCRIPT}
  echo ' --event-generator-list DefaultPlusCCMEC'           >> ${SCRIPT}
  echo ''                                                   >> ${SCRIPT}
  echo ''                                                   >> ${SCRIPT}

  ### Run Geant4 app ###################################################
  
  ROCKFILE=`shuf -n 1 ${USRDIR}/${ROCK_LISTFILE}` # Random file from the list
  COSMICS='/pnfs/dune/persistent/TaskForce_Flux/cosmics/pass3/gntp.generator-allcosmics.ghep.root'

  G4MACRO=g4_config.${JOB_NUMBER}.mac
  echo '/gastpc/geometry/magfield_strength 0.4 tesla'                                > ${G4MACRO}
  echo '/gastpc/generator/add_ghep_source '${FLAVOUR}.${i}.ghep.root' '${NU_EVENTS} >> ${G4MACRO}
  echo '/gastpc/generator/add_ghep_source rock.ghep.root '${ROCK_EVENTS}            >> ${G4MACRO}
  echo '/gastpc/generator/add_cosmics_source cosmics.ghep.root'                     >> ${G4MACRO}
  echo '/gastpc/persistency/output_file '${FLAVOUR}'.'${rnd}'.g4sim.root'           >> ${G4MACRO}

  echo 'ifdh cp '${COSMICS}' cosmics.ghep.root'             >> ${SCRIPT}
  echo 'ifdh cp '${ROCKFILE}' rock.ghep.root'               >> ${SCRIPT}
  echo 'ifdh cp '${G4MACRO}' g4_config.mac'                 >> ${SCRIPT}
  echo ''                                                   >> ${SCRIPT}
  echo 'GasTPCG4Sim -c g4_config.mac -d DUNE -g BEAM_SPILL -n 250 -r '${i}
  echo ''                                                   >> ${SCRIPT}

  ### Copy files to dCache #############################################
  echo 'ifdh cp '${FLAVOUR}.${i}.ghep.root' \'                                    >> ${SCRIPT}
  echo ${OUTDIR}/gen/${FLAVOUR}/${JOB_GROUP}/${FLAVOUR}.${JOB_NUMBER}.ghep.root   >> ${SCRIPT}
  echo ''                                                                         >> ${SCRIPT}
  echo 'ifdh cp '${FLAVOUR}'.'${rnd}'.g4sim.root \'                               >> ${SCRIPT}
  echo ${OUTDIR}/sim/${FLAVOUR}/${JOB_GROUP}/${FLAVOUR}.${JOB_NUMBER}.g4sim.root  >> ${SCRIPT}
  echo ''                                                                         >> ${SCRIPT}
  echo 'rm '${FLAVOUR}.${i}.ghep.root                                             >> ${SCRIPT}
  echo 'rm '${FLAVOUR}.${i}.g4sim.root                                            >> ${SCRIPT}
  echo 'rm cosmics.ghep.root'                                                     >> ${SCRIPT}
  echo 'rm rock.ghep.root'                                                        >> ${SCRIPT}
  echo 'rm g4_config.mac'                                                         >> ${SCRIPT}

  jobsub_submit \
   --group dune --role=Analysis -N 1 --OS=SL6 --expected-lifetime=2h \
   file://${SCRIPT}

done