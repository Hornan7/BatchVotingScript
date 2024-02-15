#!/bin/bash

# Remove former governance action files
rm -rf action-votes 2>/dev/null

MOREINDEX=1

finishing_line() {
echo -e "${LBLUE}##########################################"
echo -e "#         ${WHITE} Building Transaction         ${LBLUE} #"
echo -e "##########################################${NC}"
sleep 0.5

        #build the Transaction
        cardano-cli conway transaction build \
        --testnet-magic 4 \
        --tx-in "$(cardano-cli query utxo --address $(cat payment.addr) --testnet-magic 4 --out-file /dev/stdout | jq -r 'keys[0]')" \
        --change-address $(cat payment.addr) \
        $(cat action-votes/txvar.txt) \
        --witness-override 2 \
        --out-file vote-tx.raw

# Remove the action index options file
rm action-votes/txvar.txt

echo -e "${LBLUE}#         ${WHITE} Signing Transaction          ${LBLUE} #"
echo -e "##########################################${NC}"
sleep 0.5

        #Sign the transaction
        cardano-cli transaction sign --tx-body-file vote-tx.raw \
        --signing-key-file drep.skey \
        --signing-key-file payment.skey \
        --testnet-magic 4 \
        --out-file vote-tx.signed

echo -e "${LBLUE}#    ${WHITE} Submiting Transaction On-Chain    ${LBLUE} #"
echo -e "##########################################${NC}"
sleep 0.5

        #Submit the Transaction
        cardano-cli transaction submit \
        --testnet-magic 4 \
        --tx-file vote-tx.signed
echo -e "${LBLUE}####################################################################"
echo -e "#                   ${WHITE}Vote on governance action                      ${LBLUE}#"
echo -e "# ${WHITE}${GOVID} ${LBLUE}#"
echo -e "#                           ${WHITE}Complete                               ${LBLUE}#"
echo -e "####################################################################${NC}"
exit

}
# Prompt for more governance actions
gov_action_prompt() {
        echo -e "${LBLUE}\n##############################################################"
        echo -e "# ${WHITE}Do you want to vote on another governance action? (yes/no) ${LBLUE}#"
        echo -e "##############################################################${NC}"
        sleep 1
        echo -n "Answer: "
        read next_action_prompt
        case $next_action_prompt in
          yes)
               MOREINDEX=$((MOREINDEX+1))
               building_action_vote
          ;;
          no)

          ;;
          *)
             echo "Invalid option."
             sleep 1 # Add a small delay to allow reading of "Invalid option" before restarting the function
             gov_action_prompt
          ;;
        esac
} 
individual_vote() {
    while true; do
            if [ "$INDEXNO" != "0" ]; then
                    echo -e "${LBLUE}##########################################################################"
                    echo -e "#   ${WHITE}What is your Vote for the action index ${INDEXNO}? yes,no,abstain?   ${LBLUE}#"
                    echo -e "##########################################################################${NC}"
                    sleep 1
                    echo -n "Answer: "
                    read VOTE

                    cardano-cli conway governance vote create \
                    --${VOTE} \
                    --governance-action-tx-id "${GOVID}" \
                    --governance-action-index "${INDEXNO}" \
                    --drep-verification-key-file drep.vkey \
                    --out-file action-votes/action${MOREINDEX}-${INDEXNO}.vote
                echo " --vote-file action-votes/action${MOREINDEX}-${INDEXNO}.vote" >> action-votes/txvar.txt
                echo -e "${LBLUE}######################################"
                echo -e "# ${WHITE}Preparing vote index ${INDEXNO} of action ${MOREINDEX}${LBLUE} #${NC}"
                sleep 0.2
                INDEXNO=$((INDEXNO-1))
            else
                    echo -e "${LBLUE}##########################################################################"
                    echo -e "#   ${WHITE}What is your Vote for the action index ${INDEXNO}? yes,no,abstain?   ${LBLUE}#"
                    echo -e "##########################################################################${NC}"
                    sleep 1
                    echo -n "Answer: "
                    read VOTE

                    cardano-cli conway governance vote create \
                    --${VOTE} \
                    --governance-action-tx-id "${GOVID}" \
                    --governance-action-index "${INDEXNO}" \
                    --drep-verification-key-file drep.vkey \
                    --out-file action-votes/action${MOREINDEX}-${INDEXNO}.vote
                    echo " --vote-file action-votes/action${MOREINDEX}-${INDEXNO}.vote" >> action-votes/txvar.txt
                    echo -e "${LBLUE}# ${WHITE}Preparing vote index ${INDEXNO} of action ${MOREINDEX} ${LBLUE}#"
                    echo -e "######################################${NC}"
                    sleep 1
                    gov_action_prompt
                    finishing_line
                    break
            fi
    done
}
index_over_0_prompt() {
    INDEX_INFO=$(cardano-cli conway query gov-state --testnet-magic 4 | \
                 jq -r --arg govActionId "${GOVID}" '.proposals | to_entries[] | select(.value.actionId.txId | contains($govActionId)) | .value' | grep -c "deposit")
    if [ "$INDEX_INFO" == "0" ]; then
        echo "No active proposals found for ${GOVID}"
        exit 0
    fi
    INDEXNO=$((INDEX_INFO-1))
    echo -e "${LBLUE}######################################################################################"
    echo -e "#                         ${WHITE}HERE IS YOUR GOVERNANCE ACTION(S)                          ${LBLUE}#"
    echo -e "######################################################################################${NC}"
    cardano-cli conway query gov-state --testnet-magic 4 | \
               jq -r --arg govActionId "${GOVID}" '.proposals | to_entries[] | select(.value.actionId.txId | contains($govActionId)) | .value'
    if [ "$INDEX_INFO" != "1" ]; then
            echo -e "${LBLUE}################################################################################################################################"
            echo -e "# ${WHITE}This ID contains several governance action indexes within it. Do you want to submit the same vote for each of them? (yes,no) ${LBLUE}#"
            echo -e "################################################################################################################################${NC}"
            echo -n "Answer: "
            read ANSWER_INDEX
            if [ "$ANSWER_INDEX" = "no" ]; then
                individual_vote
            fi
    fi

}
building_action_vote() {

    #create the action file directory   
    mkdir action-votes 2>/dev/null

    sleep 1
    echo -e "${LBLUE}##########################################"
    echo -e "#   ${WHITE}What is the governance action ID?   ${LBLUE} #"
    echo -e "##########################################${NC}"
    sleep 1
    echo -n "TxId: "
    read GOVID
    sleep 0.5
    index_over_0_prompt
    sleep 0.5
    echo -e "${LBLUE}##########################################"
    echo -e "#   ${WHITE}What is your Vote? yes,no,abstain?   ${LBLUE}#"
    echo -e "##########################################${NC}"
    sleep 1
    echo -n "Answer: "
    read VOTE
    echo -e "${LBLUE}##########################################"
    echo -e "#             ${WHITE} Creating Vote            ${LBLUE} #"
    echo -e "##########################################${NC}"
    sleep 0.5

    #create the vote files
    while true; do
            if [ "$INDEXNO" != "0" ]; then
                    cardano-cli conway governance vote create \
                    --${VOTE} \
                    --governance-action-tx-id "${GOVID}" \
                    --governance-action-index "${INDEXNO}" \
                    --drep-verification-key-file drep.vkey \
                    --out-file action-votes/action${MOREINDEX}-${INDEXNO}.vote
                echo " --vote-file action-votes/action${MOREINDEX}-${INDEXNO}.vote" >> action-votes/txvar.txt
                echo -e "${LBLUE}# ${WHITE}Preparing vote index ${INDEXNO} of action ${MOREINDEX}${LBLUE} #${NC}"
                sleep 0.2
                INDEXNO=$((INDEXNO-1))
            else
                    cardano-cli conway governance vote create \
                    --${VOTE} \
                    --governance-action-tx-id "${GOVID}" \
                    --governance-action-index "${INDEXNO}" \
                    --drep-verification-key-file drep.vkey \
                    --out-file action-votes/action${MOREINDEX}-${INDEXNO}.vote
                    echo " --vote-file action-votes/action${MOREINDEX}-${INDEXNO}.vote" >> action-votes/txvar.txt
                    echo -e "${LBLUE}# ${WHITE}Preparing vote index ${INDEXNO} of action ${MOREINDEX} ${LBLUE}#"
                    echo -e "######################################${NC}"
                    sleep 1
                    gov_action_prompt
                    finishing_line
                    break
            fi
    done
}

# Stript start here #

clear
WHITE='\033[1;37m'
BLUE='\033[0;34m'
LBLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${LBLUE}###########################################################################################################################################"
echo -e "${LBLUE}##########${WHITE}@@@@@@@@@${LBLUE}##########################################${WHITE}@@@@${LBLUE}##############################${WHITE}@@@@${LBLUE}########${WHITE}@@@${LBLUE}#############################"
echo -e "########${WHITE}@@@@@@@@@@@@${LBLUE}#########################################${WHITE}@@@@${LBLUE}##############################${WHITE}@@@@@${LBLUE}#######${WHITE}@@@${LBLUE}################${WHITE}@@@${LBLUE}##########"
echo -e "########${WHITE}@@@@@@@@@@@@@${LBLUE}########################################${WHITE}@@@@${LBLUE}##############################${WHITE}@@@@@@${LBLUE}######${WHITE}@@@${LBLUE}################${WHITE}@@@${LBLUE}##########"
echo -e "#######${WHITE}@@@@${LBLUE}######${WHITE}@@@@${LBLUE}########################################${WHITE}@@@@${LBLUE}##############################${WHITE}@@@@@@.${LBLUE}#####${WHITE}@@@${LBLUE}###############${WHITE}@@@@${LBLUE}##########"
echo -e "#######${WHITE}@@@@${LBLUE}#############${WHITE}@@@@@@@@${LBLUE}###${WHITE}@@@@${LBLUE}#${WHITE}@@@@@@${LBLUE}#####${WHITE}@@@@@@@${LBLUE}###${WHITE}@@@@${LBLUE}#${WHITE}@@@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}##########${WHITE}@@@@@@@${LBLUE}#####${WHITE}@@@${LBLUE}####${WHITE}@@@@@@@@${LBLUE}#${WHITE}@@@@@@@@@@${LBLUE}######"
echo -e "#######${WHITE}@@@@@@@${LBLUE}#########${WHITE}@@@@@@@@@@${LBLUE}##${WHITE}@@@@@@@@@@@@${LBLUE}###${WHITE}@@@@@@@@@${LBLUE}##${WHITE}@@@@@@@@@@@@${LBLUE}###${WHITE}@@@@@@@@@@${LBLUE}#########${WHITE}@@@@@@@@${LBLUE}####${WHITE}@@@${LBLUE}###${WHITE}@@@@@@@@@@@@@@@@@@@@${LBLUE}######"
echo -e "########${WHITE}@@@@@@@@@@@${LBLUE}####${WHITE}@@@${LBLUE}####${WHITE}@@@@${LBLUE}#${WHITE}@@@@@@${LBLUE}##${WHITE}@@@@${LBLUE}##${WHITE}@@@@${LBLUE}###${WHITE}@@@@${LBLUE}#${WHITE}@@@@@@${LBLUE}##${WHITE}@@@@${LBLUE}##${WHITE}@@@@@${LBLUE}##${WHITE}@@@@@${LBLUE}########${WHITE}@@@@${LBLUE}#${WHITE}@@@@${LBLUE}###${WHITE}@@@${LBLUE}##${WHITE}@@@@${LBLUE}####${WHITE}@@@@${LBLUE}#${WHITE}@@@@@@@@${LBLUE}######"
echo -e "#########${WHITE}@@@@@@@@@@@@${LBLUE}#########${WHITE}.@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}#####${WHITE}@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}#####${WHITE}@@@@${LBLUE}########${WHITE}@@@@${LBLUE}##${WHITE}@@@@${LBLUE}##${WHITE}@@@${LBLUE}##${WHITE}@@@${LBLUE}#####${WHITE}@@@@${LBLUE}#${WHITE}@@@@${LBLUE}##########"
echo -e "###########${WHITE}@@@@@@@@@@${LBLUE}###${WHITE}@@@@@@@@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}#########${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}######${WHITE}@@@${LBLUE}########${WHITE}@@@@${LBLUE}###${WHITE}@@@@${LBLUE}#${WHITE}@@@${LBLUE}#${WHITE}@@@@@@@@@@@@@${LBLUE}##${WHITE}@@@${LBLUE}##########"
echo -e "#################${WHITE}@@@@@${LBLUE}#${WHITE}@@@@@@@@@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}#########${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}######${WHITE}@@@${LBLUE}########${WHITE}@@@@${LBLUE}####${WHITE}@@@@@@@${LBLUE}#${WHITE}@@@@@@@@@@@@@${LBLUE}##${WHITE}@@@${LBLUE}##########"
echo -e "#######${WHITE}@@@@${LBLUE}#######${WHITE}@@@@@@@@${LBLUE}#####${WHITE}@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}#########${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}#####${WHITE}@@@@${LBLUE}########${WHITE}@@@@${LBLUE}####${WHITE}@@@@@@@${LBLUE}#${WHITE}@@@@${LBLUE}###########${WHITE}@@@${LBLUE}##########"
echo -e "#######${WHITE}@@@@@${LBLUE}#####${WHITE}@@@@@@@@${LBLUE}#####${WHITE}@@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@@@@${LBLUE}###${WHITE}@@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@${LBLUE}#${WHITE}@@@@${LBLUE}####${WHITE}@@@@${LBLUE}########${WHITE}@@@@${LBLUE}#####${WHITE}@@@@@@${LBLUE}##${WHITE}@@@${LBLUE}#####${WHITE}@@@@${LBLUE}##${WHITE}@@@@${LBLUE}#########"
echo -e "########${WHITE}@@@@@@@@@@@@@${LBLUE}#${WHITE}@@@@@${LBLUE}#${WHITE}@@@@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@${LBLUE}#${WHITE}@@@@@@@@@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@${LBLUE}#${WHITE}@@@@@@@@@@@${LBLUE}#########${WHITE}@@@@${LBLUE}######${WHITE}@@@@@${LBLUE}##${WHITE}@@@@@@@@@@@${LBLUE}###${WHITE}@@@@@@@${LBLUE}######"
echo -e "#########${WHITE}@@@@@@@@@@@${LBLUE}##${WHITE}@@@@@@@@${LBLUE}#${WHITE}@@@${LBLUE}#${WHITE}@@@@${LBLUE}#####${WHITE}@@@@${LBLUE}##${WHITE}@@@@@@@@@${LBLUE}##${WHITE}@@@@${LBLUE}#####${WHITE}@@@@${LBLUE}##${WHITE}@@@@@@@@@${LBLUE}##########${WHITE}@@@@${LBLUE}#######${WHITE}@@@@${LBLUE}###${WHITE}@@@@@@@@@${LBLUE}####${WHITE}@@@@@@@${LBLUE}######"
echo -e "###########${WHITE}@@@@@@@${LBLUE}######${WHITE}@@@@${LBLUE}###${WHITE}@@${LBLUE}##${WHITE}@${LBLUE}##${WHITE}@${LBLUE}#####${WHITE}@@@${LBLUE}#####${WHITE}@@@@@${LBLUE}####${WHITE}@${LBLUE}#${WHITE}@${LBLUE}######${WHITE}@@@${LBLUE}#####${WHITE}@@@@@${LBLUE}############${WHITE}@@@@${LBLUE}########${WHITE}@@@${LBLUE}#####${WHITE}@@@@@${LBLUE}#########${WHITE}@@@${LBLUE}#######"
echo -e "###########################################################################################################################################"
echo -e "                                          ${YELLOW}Batch voting script version 1.01 by Mike Hornan(ABLE)${NC}"             
echo -e ""
echo -e ""
echo -e ""

building_action_vote
