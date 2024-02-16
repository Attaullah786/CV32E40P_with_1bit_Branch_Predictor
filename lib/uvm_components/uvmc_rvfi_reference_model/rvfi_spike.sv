// Copyright 2023 OpenHW Group
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef __RVFI_SPIKE_SV__
`define __RVFI_SPIKE_SV__

import "DPI-C" function int spike_create(string filename);

import "DPI-C" function void spike_set_param_uint64_t(string base, string name, longint unsigned value);
import "DPI-C" function void spike_set_param_str(string base, string name, string value);
import "DPI-C" function void spike_set_param_bool(string base, string name, bit value);
import "DPI-C" function void spike_set_default_params(string profile);

import "DPI-C" function void spike_step_svOpenArray(inout bit [63:0] core[], inout bit [63:0] reference_model[]);
import "DPI-C" function void spike_step_struct(inout st_rvfi core, inout st_rvfi reference_model);

    function automatic void rvfi_initialize_spike(string core_name, st_core_cntrl_cfg core_cfg);
        string binary, rtl_isa, rtl_priv;
        string base;

        base = $sformatf("/top/core/%0d/", core_cfg.mhartid);

        if ($value$plusargs("elf_file=%s", binary))
            `uvm_info("spike_tandem", $sformatf("Setting up Spike with binary %s...", binary), UVM_LOW);

        rtl_isa = $sformatf("RV%-2dIM",
                            core_cfg.xlen);
        rtl_priv = "M";
        if (core_cfg.ext_a_supported)       rtl_isa = {rtl_isa, "A"};
        if (core_cfg.ext_f_supported)       rtl_isa = {rtl_isa, "F"};
        if (core_cfg.ext_d_supported)       rtl_isa = {rtl_isa, "D"};
        if (core_cfg.ext_c_supported)       rtl_isa = {rtl_isa, "C"};
        if (core_cfg.ext_zba_supported)     rtl_isa = {rtl_isa, "_zba"};
        if (core_cfg.ext_zbb_supported)     rtl_isa = {rtl_isa, "_zbb"};
        if (core_cfg.ext_zbc_supported)     rtl_isa = {rtl_isa, "_zbc"};
        if (core_cfg.ext_zbs_supported)     rtl_isa = {rtl_isa, "_zbs"};
        if (core_cfg.ext_zcb_supported)     rtl_isa = {rtl_isa, "_zcb"};
        if (core_cfg.ext_zicsr_supported)     rtl_isa = {rtl_isa, "_zicsr"};
        if (core_cfg.ext_zicntr_supported)     rtl_isa = {rtl_isa, "_zicntr"};

        if (core_cfg.mode_s_supported)      rtl_priv = {rtl_priv, "S"};
        if (core_cfg.mode_u_supported)      rtl_priv = {rtl_priv, "U"};

        if (core_cfg.ext_cv32a60x_supported) begin
            void'(spike_set_param_str("/top/core/0/", "extensions", "cv32a60x"));
        end

        if (binary == "") begin
            `uvm_error("spike_tandem", "We need a preloaded binary for tandem verification");
        end

        void'(spike_set_default_params(core_name));

        void'(spike_set_param_uint64_t("/top/", "num_procs", 64'h1));

        void'(spike_set_param_str("/top/", "isa", rtl_isa));
        void'(spike_set_param_str(base, "isa", rtl_isa));
        void'(spike_set_param_str("/top/", "priv", rtl_priv));
        void'(spike_set_param_str(base, "priv", rtl_priv));
        void'(spike_set_param_bool("/top/", "misaligned", core_cfg.unaligned_access_supported));

        if (core_cfg.boot_addr_valid) begin
            void'(spike_set_param_uint64_t(base, "boot_addr", core_cfg.boot_addr));
        end

        void'(spike_set_param_uint64_t(base, "pmpregions", core_cfg.pmp_regions));
        void'(spike_set_param_uint64_t(base, "mhartid", core_cfg.mhartid));
        void'(spike_set_param_uint64_t(base, "marchid", core_cfg.marchid));
        void'(spike_set_param_uint64_t(base, "mvendorid", core_cfg.mvendorid));
        void'(spike_set_param_bool(base, "misaligned", core_cfg.unaligned_access_supported));

        if (core_cfg.dram_valid) begin
            void'(spike_set_param_uint64_t("/top/", "dram_base", core_cfg.dram_base));
            void'(spike_set_param_uint64_t("/top/", "dram_size", core_cfg.dram_size));
        end

        void'(spike_create(binary));

        void '(dasm_set_config(core_cfg.xlen, rtl_isa, 0));

    endfunction : rvfi_initialize_spike

    function automatic void rvfi_spike_step(ref st_rvfi s_core, ref st_rvfi s_reference_model);

        union_rvfi u_core;
        union_rvfi u_reference_model;
        bit [63:0] a_core [`ST_NUM_WORDS-1:0];
        bit [63:0] a_reference_model [`ST_NUM_WORDS-1:0];

        u_core.rvfi = s_core;

        foreach(u_core.array[i]) begin
            a_core[i] = u_core.array[i];
        end

        spike_step_svOpenArray(a_core, a_reference_model);

        foreach(a_reference_model[i]) begin
            u_reference_model.array[i] = a_reference_model[i];
        end
        s_reference_model = u_reference_model.rvfi;

    endfunction : rvfi_spike_step

`endif

