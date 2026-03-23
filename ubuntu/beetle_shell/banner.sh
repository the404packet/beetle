#!/bin/bash

GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

banner="
          ##########        ##########
          ##      ##        ##      ##
          ####    ####    ####    ####      
                    ########                
                    ########                
            ########################        
      ##    ########################          
      ####################################    BBBBBBBB  EEEEEEEE  EEEEEEEE  TTTTTTTT  LL        EEEEEEEE
            ########################    ##    BB    BB  EE        EE           TT     LL        EE
      ##    ########################          BBBBBBBB  EEEEEE    EEEEEE       TT     LL        EEEEEE
      ####################################    BB    BB  EE        EE           TT     LL        EE
            ########################    ##    BBBBBBBB  EEEEEEEE  EEEEEEEE     TT     LLLLLLL   EEEEEEEE
      ##    ########################
      ####################################
            ########################    ##
            ########################
                ################
                  ##        ##       
                  ##        ##  
          +----------------------------+
          |      OS HARDENING TOOL     |
          +----------------------------+
"

while IFS= read -r line; do
    for (( i=0; i<${#line}; i++ )); do
        char="${line:$i:1}"
        if [[ "$char" == "#" ]]; then
            printf "${GREEN}%s${RESET}" "$char"
        else
            printf "${CYAN}%s${RESET}" "$char"
        fi
    done
    printf "\n"
done <<< "$banner"
