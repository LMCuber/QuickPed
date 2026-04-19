import matplotlib.pyplot as plt
import numpy as np

xs = []
ys = []

with open("output.txt", "r") as f:
    lines = f.read().splitlines()
    for line in lines:
        data = [int(x) for x in line.split("|")]
        if data[0] in xs:
            continue
        xs.append(data[0])
        ys.append(data[1])

n = np.linspace(1, len(xs), len(xs))
nlogn = n * np.log2(n)

plt.plot(xs, ys)
plt.plot(n, nlogn)
plt.show()
