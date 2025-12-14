Hardware folder layout and quick run steps

Place sources in `verilog/`, data files in `datafiles/`, and the `filelist` in `sim/`.

Run steps (for reference):
```pwsh
cd Part3_Reconfigurable/hardware/sim
iveri filelist
irun
```

The default testbench should exercise all reconfigurable modes without recompilation.

data files' filename format:
1) activation: activation.txt
2) weight: weight_itile0_otile0_kij0_fixed.txt, etc.
3) golden psum: psum_0.txt, etc.
4) golden psum after accumulation and ReLU: psum_relu.txt
