.PHONY: help tiny tiny-cu tiny-input small small-cu small-input \
	digits digits-cu digits-input venv show

help:
	@echo "usage: make {tiny, tiny-cu, small, small-cu, digits, digits-cu}"

tiny: tiny-input
	rm -f out.npy
	bend run main.bend 4
	make show

tiny-cu: tiny-input
	rm -f out.npy
	bend run-cu main.bend 4
	make show

tiny-input: .venv
	.venv/bin/python -c "import numpy as np; np.random.seed(0); \
		np.save('in.npy', np.random.normal(size=(8, 3)))"

small: small-input
	rm -f out.npy
	bend run main.bend 8
	make show

small-cu: small-input
	rm -f out.npy
	bend run-cu main.bend 8
	make show

small-input: .venv
	.venv/bin/python -c "import numpy as np; np.random.seed(0); \
		np.save('in.npy', np.random.normal(size=(32, 5)))"

digits: digits-input
	rm -f out.npy
	bend run main.bend 15
	make show

digits-cu: digits-input
	rm -f out.npy
	bend run-cu main.bend 15
	make show

digits-input: .venv
	.venv/bin/python -c "import numpy as np; import sklearn.datasets as skd; \
		np.save('in.npy', skd.load_digits().data)"

venv:
	@if ! which python >/dev/null; then exit 1; fi
	if [ ! -d .venv ]; then python -m venv .venv; fi
	if [ ! -d .venv/lib/*/site-packages/numpy ]; \
		then .venv/bin/pip install -U numpy; fi
	if [ ! -d .venv/lib/*/site-packages/sklearn ]; \
		then .venv/bin/pip install -U scikit-learn; fi

.venv: venv

show: out.npy
	python -c "import numpy as np; print(np.load('out.npy'))"
