#-----------------------------------------------------------------------------
# MegaSoC Top-Level Makefile 
# - Includes other Makefiles in flow directory
# A joint work commissioned on behalf of SoC Labs, under Arm Academic Access license.
#
# Contributors
#
# David Flynn (d.w.flynn@soton.ac.uk)
# Daniel Newbrook (d.newbrook@soton.ac.uk)
# Copyright (C) 2021-3, SoC Labs (www.soclabs.org)
#-----------------------------------------------------------------------------

#-------------------------------------
# - Commonly Overloaded Variables
#-------------------------------------
# Name of test directory - Default Test is Hello World
TESTNAME   ?= hello

# Simulator type (mti/vcs/xm)
SIMULATOR   = mti

# Is an accelerator subsystem present in the design?
ACCELERATOR ?= yes

#-------------------------------------
# - Directory Setups
#-------------------------------------
# Directory of Testcodes
TESTCODES_DIR    := $(SOCLABS_MEGASOC_TECH_DIR)/testcodes

# Project System Directory
FPGA_IMP_DIR     := $(SOCLABS_PROJECT_DIR)/imp/fpga
PROJ_SYS_DIR     := $(SOCLABS_PROJECT_DIR)/system
PROJ_SW_DIR      ?= $(PROJ_SYS_DIR)/testcodes

# Directory to put simulation files
SIM_TOP_DIR ?= $(SOCLABS_PROJECT_DIR)/simulate/sim
SIM_DIR      = $(SIM_TOP_DIR)/$(TESTNAME)

# Config Directory
THIS_DIR	 := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CONFIG_DIR   := $(THIS_DIR)/config

# Source Directory
SRC_DIR	     := $(abspath $(THIS_DIR)/src)

#-------------------------------------
# - DMA-350 Generation Scripts
#-------------------------------------
DMA350_GENERATE_SCRIPT := $(ARM_IP_LIBRARY_PATH)/DMA-350/CG096-r0p0-00rel0/CG096-BU-50000-r0p0-00rel0/dma350/logical/generate

#-------------------------------------
# - XHB500 Generation Scripts
#-------------------------------------
XHB500_GENERATE_SCRIPT := $(ARM_IP_LIBRARY_PATH)/DMA-350/CG096-r0p0-00rel0/PL417-BU-50000-r0p1-00rel0/xhb500/logical/generate

#-------------------------------------
# - DMA-350 IP Configuration Targets
#-------------------------------------
config_dma_ahb:          $(SRC_DIR)/dma_ahb          $(SRC_DIR)/xhb_axi_to_ahb
config_dma_ahb_small:    $(SRC_DIR)/dma_ahb_small    $(SRC_DIR)/xhb_axi_to_ahb
config_dma_ahb_big:      $(SRC_DIR)/dma_ahb_big      $(SRC_DIR)/xhb_axi_to_ahb_big
config_dma_axi:          $(SRC_DIR)/dma_axi
config_dma_axi_millisoc: $(SRC_DIR)/dma_axi_millisoc

$(SRC_DIR)/dma_%: $(CONFIG_DIR)/cfg_dma_%.yaml
	@$(DMA350_GENERATE_SCRIPT) --config $^ --output $@
	
$(SRC_DIR)/xhb_axi_to_%: $(CONFIG_DIR)/cfg_xhb_axi_to_%.cfg
	@$(XHB500_GENERATE_SCRIPT) --config $^ --output $@

clean_ip:
	@rm -rf ./src/*