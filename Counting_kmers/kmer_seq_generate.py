import sys
import re
import string
import json
from collections import Counter
import pathlib



kmer = int(sys.argv[1])
dir_name = "./"+sys.argv[1] + "mer/"
pathlib.Path(dir_name).mkdir(parents=True, exist_ok=True) 

seq_dict = {}
seq_list = []

temp_fasta = []
count = 0
start_file_flag = 0
file_count =1
output_count = 0
with open("uniref90_infl.fasta") as file_one:
    for line in file_one:
        line = line.strip()
        if start_file_flag !=1:
            start_file_flag = 1
            continue
        if line.startswith(">") or not line:
            count = count + 1
            output_count+=1
            fasta = ''.join(temp_fasta).replace("*","")
            #print("Sequence " + str(count) + ":" + fasta)
            for j in range(0, len(fasta) - kmer+1):
                seq_list.append(fasta[j : j + kmer])

            if count == 1000000:
                file_name = dir_name+str(kmer)+"mer_output"+str(file_count)+".txt"
                with open(file_name,'w') as f:
                    print('Filename:', Counter(seq_list), file=f)
                count = 0
                file_count+=1
                seq_list=[]
            
            print("Reading Sequence "+ str(output_count) + "complete")

            fasta = ""
            temp_fasta = []
            continue

        temp_fasta.append(line)

count = count + 1
output_count+=1
fasta = ''.join(temp_fasta).replace("*","")
#print("Sequence " + str(count) + ":" + fasta)
for j in range(0, len(fasta) - kmer+1):
    seq_list.append(fasta[j : j + kmer])
    
print("Reading Sequence "+ str(output_count) + "complete")

fasta = ""
temp_fasta = []

file_name = dir_name+str(kmer)+"mer_output"+str(file_count)+".txt"
with open(file_name,'w') as f:
    print('Filename:', Counter(seq_list), file=f)
