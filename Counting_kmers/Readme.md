Please follow the steps below to run the python file to generate kmer

# Step 1
Update the filename with your fasta file inside kmer_seq_generate.py

# Step 2
Run the kmer_seq_generate.py with kmer as command line argument
(E.g. python3 kmer_seq_generate.py 4) where 4 specifies that you want to create 4mer from your sequence

# Step 3
After the intermediate files are generated through batch processing update the file count inside combine_interm_seq.py

# Step 4
Run the combine_interm_seq.py with kmer as command line argument
(E.g. python3 combine_interm_seq.py 4) where 4 specifies that you want to combine intermediate result of 4mers inside 4mer folder
