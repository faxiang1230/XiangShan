SINGLE_EMU=${NOOP_HOME}/single-build/emu -b 0 -e 0 --diff=${NOOP_HOME}/ready-to-run/riscv64-nemu-interpreter-so
DUAL_EMU=${NOOP_HOME}/dual-build/emu -b 0 -e 0 --diff=${NOOP_HOME}/ready-to-run/riscv64-nemu-interpreter-dual-so
ARCH=riscv64-xs
MAKEFLAGS=-j

LOG_DIR=${NOOP_HOME}/result-`date "+%y-%m-%d"`
RESULT=${LOG_DIR}/result.txt
define REPORT
if [ $$? != 0 ];then \
	echo "$@ \033[31m [FAILED]\033[0m" >>${RESULT}; \
	exit 255; \
	else\
	echo "$@ \033[32m [SUC]\033[0m" >>${RESULT}; \
	exit 0; \
	fi
endef


export SINGLE_EMU DUAL_EMU ARCH LOG_DIR RESULT

.PHONY: pre post nexus-am coremark

test: pre nexus-am localtest
pre:
	@mkdir -p $(LOG_DIR)

nexus-am: pre
	$(MAKE) -C ${AM_HOME} build -j1
	$(MAKE) -C ${AM_HOME} test $(MAKEFLAGS)

GITHUB_DIR=/nfs/home/share/autotest
SPEC_DIR=/nfs-nvme/home/share/checkpoints_profiles
SPEC_ENTRY=spec06_rv64gcb_o2_20m spec06_rv64gcb_o3_20m spec06_rv64gc_o2_20m spec06_rv64gc_o2_50m
SPEC_ENTRY +=spec17_rv64gcb_o2_20m spec17_rv64gcb_o3_20m spec17_rv64gc_o2_50m spec17_speed_rv64gcb_o3_20m
${SPEC_ENTRY}:pre
	python3 $(GITHUB_DIR)/env-scripts/perf/xs_autorun.py $(SPEC_DIR)/$@/take_cpt $(SPEC_DIR)/$@/json/simpoint_summary.json --xs ${NOOP_HOME} --threads 8 --dir SPEC06_EmuTasks_$(date "+%d-%m-%y")

NFS1=/nfs/home/share/ci-workloads/
OTHER_BINARY=asid/asid.bin Svinval/rv64mi-p-svinval.bin pmp/pmp.riscv.bin linux-hello/bbl.bin
OTHER_BINARY_DUAL=linux-hello-smp/bbl.bin
${OTHER_BINARY}:pre
	@$(SINGLE_EMU) -i $(addprefix $(NFS1),$@) >>$(LOG_DIR)/$(notdir $@).log 2>&1;$(REPORT)
${OTHER_BINARY_DUAL}:pre
	@$(DUAL_EMU) -i $(addprefix $(NFS1),$@) >>$(LOG_DIR)/$(notdir $@).log 2>&1;$(REPORT)
coremark:pre
	$(MAKE) -C ${AM_HOME}/apps/coremark ARCH=riscv64-xs-flash
	@-cp ${AM_HOME}/apps/coremark/build/coremark-riscv64-xs-flash.bin $(LOG_DIR)/ 
	${NOOP_HOME}/single-build/emu -F $(LOG_DIR)/coremark-riscv64-xs-flash.bin -i $(NOOP_HOME)/ready-to-run/coremark-2-iteration.bin

localtest: $(OTHER_BINARY) $(OTHER_BINARY_DUAL) $(CORE_MARK) $(SPEC_ENTRY)

