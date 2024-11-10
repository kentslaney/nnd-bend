tiny:
	python -c "import numpy as np; np.random.seed(0); \
		np.save('in.npy', np.random.normal(size=(8, 3)))"
	bend run main.bend 4
	make show

small:
	python -c "import numpy as np; np.random.seed(0); \
		np.save('in.npy', np.random.normal(size=(32, 5)))"
	bend run main.bend 8
	make show

digits:
	python -c "import numpy as np; from sklearn.datasets import load_digits; \
		np.save('in.npy', load_digits().data)"
	bend run main.bend 15
	make show

show: out.npy
	python -c "import numpy as np; print(np.load('out.npy'))"
