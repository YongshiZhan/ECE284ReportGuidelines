# Software Alpha 2

- This is a software only alpha
- We implemented BERT and split the matmuls in FFN blocks and ran them on our systolic array
- We split the matmuls into logical 8x8 matmuls and ran them on our accelerator
- We performed sensitivity studies on the effects of quantization and realized energy savings (refer to report for more details)
