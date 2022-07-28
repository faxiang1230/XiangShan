SINGLE_EMU=numactl -m 0 -C 0-127 ${NOOP_HOME}/single-build/emu -b 0 -e 0 --diff=${NOOP_HOME}/ready-to-run/riscv64-nemu-interpreter-so
DUAL_EMU=numactl -m 0 -C 0-127 ${NOOP_HOME}/dual-build/emu -b 0 -e 0 --diff=${NOOP_HOME}/ready-to-run/riscv64-nemu-interpreter-dual-so
ARCH=riscv64-xs
MAKEFLAGS=-j

LOG_DIR=${NOOP_HOME}/result-`date "+%y-%m-%d"`
RESULT=${LOG_DIR}/result.txt
define REPORT
if [ $$? != 0 ];then \
	echo "$(1)$@ `date +"%D %T"` \033[31m [FAILED]\033[0m" >>${RESULT}; \
	exit 255; \
	else\
	echo "$(1)$@ `date +"%D %T"` \033[32m [SUC]\033[0m" >>${RESULT}; \
	exit 0; \
	fi
endef


export SINGLE_EMU DUAL_EMU ARCH LOG_DIR RESULT

.PHONY: pre post nexus-am coremark

test: pre nexus-am localtest tl_test linux_test liunx_distr_test riscv-test
	#python3 mail.py --sender=username@163.com --passwd XXXXX --receiver username@qq.com --smtpserver smtp.163.com --subject 'XiangShan test' --text 'test complete'
ifeq ($(AM_HOME),)
	echo "AM_HOME not defined!"
	exit
endif
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

########################huancun test###############################
HUANCUN=$(GITHUB_DIR)/huancun
HUANCUN_TEST_LOG=$(LOG_DIR)/huancun
huancun-l2: | $(HUANCUN)
	mkdir -p $(HUANCUN_TEST_LOG)
	cd $(HUANCUN); make init; make clean; make test-top-l2 > $(HUANCUN_TEST_LOG)/$@.log 2>&1; $(REPORT)

huancun-l2l3: | $(HUANCUN)
	mkdir -p $(HUANCUN_TEST_LOG)
	cd $(HUANCUN); make init; make clean; make test-top-l2l3 > $(HUANCUN_TEST_LOG)/$@.log 2>&1; $(REPORT)
$(HUANCUN):
	mkdir -p $@
	git clone -b nanhu https://github.com/OpenXiangShan/HuanCun.git $@
############################tl-test###############################
tl_subtest = 7525 8342 8000 8323 2345 9111 8212 4120 1568 4999
tl_subtest-l2l3 = 9210 1230 2453 8600 8020 6700 9020 2340 9000 6900
TL_TEST=$(GITHUB_DIR)/tl_test
TL_TEST_LOG=$(LOG_DIR)/tl_test

tl_test:
	$(MAKE) tl_test-l2
	$(MAKE) tl_test-l2l3

tl_test-l2: $(tl_subtest)
$(tl_subtest): tl_make-l2
	mkdir -p $(TL_TEST_LOG)
	$(TL_TEST)/build/tlc_test -s $@ -c 100000 > $(TL_TEST_LOG)/l2_$@.log 2>&1; $(call REPORT, tl_test-l2-)
tl_make-l2: | $(TL_TEST)
	$(MAKE) huancun-l2
	cd $(TL_TEST); mkdir -p build; cd build; cmake .. -DDUT_DIR=$(HUANCUN)/build -DTRACE=1 -DTHREAD=4; make clean; make

tl_test-l2l3: $(tl_subtest-l2l3)
$(tl_subtest-l2l3): tl_make-l2l3
	mkdir -p $(TL_TEST_LOG)
	$(TL_TEST)/build/tlc_test -s $@ -c 100000 > $(TL_TEST_LOG)/l2l3_$@.log 2>&1; $(call REPORT, tl_test-l2l3-)
tl_make-l2l3: | $(TL_TEST)
	$(MAKE) huancun-l2l3
	cd $(TL_TEST); mkdir -p build; cd build; cmake .. -DDUT_DIR=$(HUANCUN)/build -DTRACE=1 -DTHREAD=8; make clean; make
$(TL_TEST):
	mkdir -p $@
	git clone -b b-boost https://github.com/OpenXiangShan/tl-test.git $@
######################linux test###################################
LINUX_PATH=/nfs-nvme/home/share/xs-workloads
LINUX_BIN = linux-4.18-coremarkpro linux-4.18-redis linux-4.18-debian linux-4.18-hello #linux-4.18-smp-hello
LINUX_SMP_BIN = linux-4.18-smp-hello
linux_test: $(LINUX_BIN) $(LINUX_SMP_BIN)
LINUX_TEST_LOG=$(LOG_DIR)/linux_test
$(LINUX_BIN):
	mkdir -p $(LINUX_TEST_LOG)
	#$(NEMU_HOME)/build/riscv64-nemu-interpreter -b $(LINUX_PATH)/$@/bbl.bin > $(LOG_DIR)/$@_nemu.log  2>&1
	$(NUMACTL) $(SINGLE_EMU) -i $(LINUX_PATH)/$@/bbl.bin > $(LINUX_TEST_LOG)/$@.log 2>&1; $(REPORT)
$(LINUX_SMP_BIN):
	#$(NEMU_HOME)/build/riscv64-nemu-interpreter -b $(LINUX_PATH)/$@/bbl.bin > $(LOG_DIR)/$@_nemu.log  2>&1
	$(NUMACTL) $(DUAL_EMU) -i $(LINUX_PATH)/$@/bbl.bin > $(LINUX_TEST_LOG)/$@.log 2>&1; $(REPORT)
#####################Linux distributions test#######################
DEBIAN_IMG=/nfs-nvme/home/share/xs-workloads/debians/riscv-debian-default.img
FEDORA_IMG=/nfs-nvme/home/share/xs-workloads/fedoras/fedora-mini.img
bbl_bin=/nfs/home/share/autotest/linux_distr_bbl.bin
LINUX_DISTR_LOG=$(LOG_DIR)/linux_distr_test
linux_distr_test: debian_test fedora_test
debian_test:
	mkdir -p $(LINUX_DISTR_LOG)
	$(NUMACTL) $(SINGLE_EMU) -i $(bbl_bin) -c $(DEBIAN_IMG) > $(LINUX_DISTR_LOG)/$(notdir $@).log 2>&1; $(REPORT)
fedora_test:
	mkdir -p $(LINUX_DISTR_LOG)
	$(NUMACTL) $(SINGLE_EMU) -i $(bbl_bin) -c $(FEDORA_IMG) > $(LINUX_DISTR_LOG)/$(notdir $@).log 2>&1; $(REPORT)
######################riscv tests###################################
RISCV_TESTS=$(GITHUB_DIR)/riscv-tests
RISCV_TESTS_LOG=$(LOG_DIR)/riscv-tests
riscv-test: isa_test_make
	$(MAKE) isa_test
	$(MAKE) pma_test
isa_test_bin = $(wildcard $(RISCV_TESTS)/isa/build/*.bin)

isa_test: $(isa_test_bin)
$(isa_test_bin): isa_test_make
	mkdir -p $(RISCV_TESTS_LOG)
	$(NUMCTL) $(SINGLE_EMU) -i $@ --diff=$(NOOP_HOME)/ready-to-run/riscv64-nemu-interpreter-so >> $(RISCV_TESTS_LOG)/$(notdir $@).log 2>&1; $(REPORT)

isa_test_make: | $(RISCV_TESTS)
	cd $(RISCV_TESTS)/isa; make bin ENV=xs

pma_test: | $(RISCV_TESTS)
	mkdir -p $(RISCV_TESTS_LOG)
	cd $(RISCV_TESTS)/benchmarks; make clean; make;
	$(NUMCTL) $(DUAL_EMU) -i $(abspath $(RISCV_TESTS)/benchmarks/pma.bin) >> $(RISCV_TESTS_LOG)/$@.log 2>&1; $(REPORT)
$(RISCV_TESTS):
	mkdir -p $@
	git clone -b noop https://github.com/OpenXiangShan/riscv-tests.git $@

