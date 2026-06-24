# print.sg_image reports grayscale, multichannel, resolution, history

    Code
      print(new_sg_image(matrix(0, 4, 4)))
    Message
      <sg_image>: 4 x 4 (1 channel)

---

    Code
      print(multi)
    Message
      <sg_image>: 4 x 4 x 2 (2 channels: a, b)
      Resolution: 0.5 x 0.5 um/px
      History: denoise -> stretch

