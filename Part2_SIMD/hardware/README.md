Hardware folder layout and quick run steps

Place sources in `verilog/`, data files in `datafiles/`, and the `filelist` in `sim/`.

Run steps (for reference):
```pwsh
cd Part2_SIMD/hardware/sim
iveri filelist
irun
```

The default testbench should cover both 2-bit and 4-bit modes without recompilation.

data files' filename format:
1) activation: data_2b_act.txt, data_4b_act.txt
2) weight: data_2b_wgt_otile0_kij0.txt, data_2b_wgt_otile0_kij1.txt, etc.
3) golden psum: data_2b_psum_kij0, etc.
4) golden psum after accumulation and ReLU: data_2b_psum_relu.txt, data_4b_psum_relu.txt
