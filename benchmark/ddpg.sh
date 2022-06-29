poetry install -E "mujoco pybullet"
poetry run python -c "import mujoco_py"
OMP_NUM_THREADS=1 xvfb-run -a python -m cleanrl_utils.benchmark \
    --env-ids HalfCheetah-v2 Walker2d-v2 Hopper-v2 \
    --command "poetry run python cleanrl/ddpg_continuous_action.py --track --capture-video" \
    --num-seeds 3 \
    --workers 3

poetry install -E "mujoco jax"
poetry run pip install --upgrade "jax[cuda]==0.3.14" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
poetry run python -c "import mujoco_py"
OMP_NUM_THREADS=1 xvfb-run -a python -m cleanrl_utils.benchmark \
    --env-ids HalfCheetah-v2 Walker2d-v2 Hopper-v2 \
    --command "poetry run python cleanrl/ddpg_continuous_action_jax.py --track --capture-video" \
    --num-seeds 3 \
    --workers 1
