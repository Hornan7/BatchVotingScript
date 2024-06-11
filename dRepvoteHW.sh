#!/bin/bash

# Remove former governance action files
rm -rf action-votes 2>/dev/null

MOREINDEX=1
GOVNO=1

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
        cardano-hw-cli transaction transform \
        --tx-file vote-tx.raw \
        --out-file tx.transformed

        rm payment.witness 2>/dev/null
        rm drep.witness 2>/dev/null

        #create the payment witness
        cardano-hw-cli transaction witness \
        --tx-file tx.transformed \
        --hw-signing-file payment.hwsfile \
        --hw-signing-file drep.hwsfile \
        --testnet-magic 4 \
        --out-file payment.witness \
        --derivation-type LEDGER
        
        cardano-cli conway transaction assemble \
        --tx-body-file tx.transformed \
        --witness-file payment.witness \
        --out-file vote-tx.signed

echo -e "${LBLUE}#    ${WHITE} Submiting Transaction On-Chain    ${LBLUE} #"
echo -e "##########################################${NC}"
sleep 0.5

        #Submit the Transaction
        cardano-cli conway transaction submit \
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
                if [[ "$VOTEALL" != "yes" || "$VOTEALL" != "Yes" ]]; then
                    individual_vote
                fi
            fi
    fi

}
vote_all() {

        #query the number of governance actions
        ALLGOVID=$(cardano-cli conway query gov-state --testnet-magic 4 | jq .proposals | grep -c "deposit")
        
        #query the current epoch number
        EPOCHNO=$(cardano-cli conway query tip --testnet-magic 4 | jq -r .epoch)

        #loop to vote on everything thats not expired
        if [[ "$VOTEALL" == "yes" || "$VOTEALL" == "Yes" ]]; then
        while [ "$GOVNO" -le "$ALLGOVID" ]; do
            #query the governance action id            
            GOVID=$(cardano-cli conway query gov-state --testnet-magic 4 | jq .proposals[] | jq -r .actionId.txId | sed -n "${GOVNO}p")
            #query the governance action expiry
            GOVEXPIRY=$(cardano-cli conway query gov-state --testnet-magic 4 | jq -r --arg govActionId "${GOVID}" '.proposals | to_entries[] | select(.value.actionId.txId | contains($govActionId)) | .value.expiresAfter')
            
            #build the vote if the governance action is not expired
            if [ "$EPOCHNO" -le "$GOVEXPIRY" ]; then
                    echo -e "${LBLUE}######################################################################################"
                    echo -e "#                         ${WHITE}HERE IS THE GOVERNANCE ACTION NUMBER ${GOVNO}                    ${LBLUE}#"
                    echo -e "######################################################################################${NC}"
                    cardano-cli conway query gov-state --testnet-magic 4 | jq -r --arg govActionId "${GOVID}" '.proposals | to_entries[] | select(.value.actionId.txId | contains($govActionId)) | .value'
                    INDEXNO=$(cardano-cli conway query gov-state --testnet-magic 4 | jq -r --arg govActionId "${GOVID}" '.proposals | to_entries[] | select(.value.actionId.txId | contains($govActionId)) | .value.actionId.govActionIx')
                    echo -e "${LBLUE}##################################################################################"
                    echo -e "#   ${WHITE}What is your Vote for the action number ${GOVNO}? yes,no,abstain?                  ${LBLUE}#"
                    echo -e "##################################################################################${NC}"
                    echo -n "Answer: "
                    read VOTE

                    #check if the vote is valid
                    while [[ "$VOTE" != "yes" && "$VOTE" != "no" && "$VOTE" != "abstain" ]]; do
                        echo -e "${LBLUE}##########################################################################"
                        echo -e "#       ${WHITE}Invalid vote. Please enter yes, no, or abstain only:             ${LBLUE}#"
                        echo -e "##########################################################################${NC}"
                        echo -n "Answer: "
                        read VOTE
                    done

                    #check if the user wants to provide an anchor
                    if [[ "$VOTE_ANCHOR" == "yes" || "$VOTE_ANCHOR" == "Yes" ]]; then
                        echo -e "${LBLUE}####################################################################################################"
                        echo -e "#   ${WHITE}Would you like to provide an anchor to justify your vote for this governance action? (yes/no) ${LBLUE} #"
                        echo -e "####################################################################################################${NC}"
                        echo -n "Answer: "
                        read ANCHOR_PROMPT
                        if [[ "$ANCHOR_PROMPT" == "yes" || "$ANCHOR_PROMPT" == "Yes" ]]; then
                        echo "Please enter the anchor URL link"
                        read ANCHOR
                        mkdir vote-anchors 2>/dev/null
                        wget $ANCHOR -P vote-anchors 2>/dev/null
                        HASH=$(cardano-cli conway governance hash anchor-data --file-text vote-anchors/$(basename $ANCHOR))
                        echo -e "${LBLUE}##############################################################################################################################################"
                        echo -e "# ${WHITE}The URL link to your anchor and its hash ${HASH} has been included into your vote${LBLUE} #"
                        echo -e "##############################################################################################################################################${NC}"
                        sleep 1
                        echo -e "${LBLUE}###################################################################################"
                        echo -e "# ${WHITE}You can find your anchor file $(basename $ANCHOR) in the vote-anchors directory${LBLUE} #"
                        echo -e "###################################################################################${NC}"
                        sleep 1
                        fi
                    fi

                    # Add the anchor to the vote file if the user agreed to it
                    if [[ "$ANCHOR_PROMPT" == "yes" || "$ANCHOR_PROMPT" == "Yes" ]]; then
                        cardano-cli conway governance vote create \
                        --${VOTE} \
                        --governance-action-tx-id "${GOVID}" \
                        --governance-action-index "${INDEXNO}" \
                        --drep-verification-key-file drep.vkey \
                        --anchor-url ${ANCHOR} \
                        --anchor-data-hash ${HASH} \
                        --out-file action-votes/action${MOREINDEX}-${INDEXNO}.vote
                        sleep 1
                        echo -e "${LBLUE}#####################################################"
                        echo -e "# ${WHITE}Here is your vote file with your anchor and hash ${LBLUE} #"
                        echo -e "#####################################################${NC}"
                        sleep 0.5

                        #view the vote file
                        cardano-cli conway governance vote view --output-json --vote-file action-votes/action${MOREINDEX}-${INDEXNO}.vote
                        echo ""
                        echo -e "${LBLUE}####################################################"
                        echo -e "# ${WHITE}If its ok with you, shall we carry on? (yes/no) ${LBLUE} #"
                        echo -e "####################################################${NC}"
                        echo -n "Answer: "
                        read YES_OR_NO
                        if [[ "$YES_OR_NO" == "no" || "$YES_OR_NO" == "No" ]]; then
                            echo -e "${LBLUE}#################################################"
                            echo -e "# ${WHITE}Ok, we will not submit this vote. Exiting... ${LBLUE} #"
                            echo -e "#################################################${NC}"
                            exit 0
                        fi
                        sleep 0.5
                    else
                        cardano-cli conway governance vote create \
                        --${VOTE} \
                        --governance-action-tx-id "${GOVID}" \
                        --governance-action-index "${INDEXNO}" \
                        --drep-verification-key-file drep.vkey \
                        --out-file action-votes/action${MOREINDEX}-${INDEXNO}.vote
                    fi

                #append the vote file to the txvar.txt
                echo " --vote-file action-votes/action${MOREINDEX}-${INDEXNO}.vote" >> action-votes/txvar.txt
                echo -e "${LBLUE}######################################"
                echo -e "# ${WHITE}Preparing vote for action ${GOVNO}${LBLUE}       #${NC}"
                sleep 0.2
                else
                echo -e "${LBLUE}#########################################################################################################"
                echo -e "#                         ${WHITE}THE GOVERNANCE ACTION ${GOVNO} HAS EXPIRED, MOVING TO THE NEXT ONE                   ${LBLUE}#"
                echo -e "#########################################################################################################${NC}"
                sleep 1
            fi
            MOREINDEX=$((MOREINDEX+1))
            GOVNO=$((GOVNO+1))
        done
        finishing_line
        fi
}
building_action_vote() {

    #create the action file directory   
    mkdir action-votes 2>/dev/null

    sleep 1
    echo -e "${LBLUE}#################################################################"
    echo -e "#   ${WHITE}Would you like to vote on all governance actions? (yes/no) ${LBLUE} #"
    echo -e "#################################################################${NC}"
    echo -n "Answer: "
    read VOTEALL
    if [[ "$VOTEALL" == "yes" || "$VOTEALL" == "Yes" ]]; then
        echo -e "${LBLUE}################################################################################"
        echo -e "#   ${WHITE}Would you like to provide anchors to justify some of your votes? (yes/no) ${LBLUE} #"
        echo -e "################################################################################${NC}"
        echo -n "Answer: "
        read VOTE_ANCHOR
        vote_all
    fi
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
                sleep 0.1
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
echo -e "                                          ${YELLOW}Batch voting script version 1.02 by Mike Hornan(ABLE)${NC}"             
echo -e ""
echo -e ""
echo -e ""

building_action_vote
