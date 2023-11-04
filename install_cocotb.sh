# create venv
python3 -m venv venv_sparse

# source venv
. ./venv_sparse/bin/activate

# upgrade pip
python3 -m pip install --upgrade pip

# install all required libraries
python3 -m pip install -r requirements.txt
