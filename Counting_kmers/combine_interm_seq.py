from collections import Counter
import ast
import sys

kmer = int(sys.argv[1])
dir_name = "./"+sys.argv[1] + "mer/"

final_dict = {}
for i in range(1,71):
    filename = dir_name+str(kmer)+"mer_output"+str(i)+".txt"
    textfile = open(filename, 'r')
    filetext = textfile.read()
    textfile.close()
    dict_val=filetext.strip().split("(")[1][:-1]
    val = ast.literal_eval(dict_val)
    print(filename + " Processed")

    final_dict = dict(Counter(final_dict) + Counter(val))

output_f = dir_name+str(kmer)+"mers_uniref90.txt"
with open(output_f,'w') as f:
    print('Sequence:', Counter(final_dict), file=f)
