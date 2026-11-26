import os
import numpy as np
import matplotlib.pyplot as plt

def tokenizer(fname):
    with open(fname) as f:
        title = ""
        chunk = []
        in_chunk = False
        for line in f:
            if 'histogram' in line:
                if in_chunk:
                    yield title, chunk[2:]
                title = line.split(':', 1)[1].strip()
                chunk = []
                in_chunk = True
                continue

            chunk.append(line)

        if in_chunk:
            yield title, chunk[2:]

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()

    parser.add_argument("filenames", nargs='+', help="Plot histograms in these files")

    args = parser.parse_args()
    print(args)

    for i, fname in enumerate(args.filenames):
        print("Processing file '%s'..." %(fname))
        basename = os.path.splitext(fname)[0]

        histograms = [(t, np.loadtxt(l)) for t, l in tokenizer(fname)]

        for j, histo in enumerate(histograms):
            np.savetxt("%s_h%02i.dat" % (basename, j), histo[1][:, 1:], fmt='%.6e', header=histo[0])

            fig = plt.figure()
            ax = fig.add_subplot(111)

            ax.plot(histo[1][:, 1], histo[1][:, 2], '-')

            ax.set_title(histo[0])

            plt.xlabel('X')
            plt.ylabel('Y')

            plt.draw()

            plt.savefig("%s_h%02i.png" % (basename, j), format = 'png', bbox_inches='tight')

            plt.clf()
            plt.close()

    print('Done!!!!')
