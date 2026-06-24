# print.sg_mask prints dims, count and method

    Code
      print(m)
    Message
      <sg_mask>: 2 x 2, 2 cells
      Method: watershed

# summary.sg_mask reports empty masks

    Code
      summary(new_sg_mask(matrix(0L, 4, 4)))
    Message
      Empty mask (no cells)

