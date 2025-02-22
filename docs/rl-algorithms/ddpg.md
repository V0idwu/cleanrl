# Deep Deterministic Policy Gradient (DDPG)


## Overview

DDPG is a popular DRL algorithm for continuous control. It extends DQN to work with the continuous action space by introducing a deterministic actor that directly outputs continuous actions. DDPG also combines techniques from DQN, such as the replay buffer and target network.


Original paper: 

* [Continuous control with deep reinforcement learning](https://arxiv.org/abs/1509.02971)

Reference resources:

* :material-github: [sfujim/TD3](https://github.com/sfujim/TD3)
* [Deep Deterministic Policy Gradient | Spinning Up in Deep RL](https://spinningup.openai.com/en/latest/algorithms/ddpg.html)
* :material-github: [ikostrikov/jaxrl](https://github.com/ikostrikov/jaxrl) (helpful reference when implemented [`ddpg_continuous_action_jax.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action_jax.py))

## Implemented Variants


| Variants Implemented      | Description |
| ----------- | ----------- |
| :material-github: [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py), :material-file-document: [docs](/rl-algorithms/ddpg/#ddpg_continuous_actionpy) | For continuous action space |


Below is our single-file implementation of DDPG:

## `ddpg_continuous_action.py`

The [ddpg_continuous_action.py](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) has the following features:

* For continuous action space
* Works with the `Box` observation space of low-level features
* Works with the `Box` (continuous) action space

### Usage

```bash
poetry install
poetry install -E pybullet
python cleanrl/ddpg_continuous_action.py --help
python cleanrl/ddpg_continuous_action.py --env-id HopperBulletEnv-v0
poetry install -E mujoco # only works in Linux
python cleanrl/ddpg_continuous_action.py --env-id Hopper-v3
```

### Explanation of the logged metrics

Running `python cleanrl/ddpg_continuous_action.py` will automatically record various metrics such as actor or value losses in Tensorboard. Below is the documentation for these metrics:

* `charts/episodic_return`: episodic return of the game
* `charts/SPS`: number of steps per second
* `losses/qf1_loss`: the mean squared error (MSE) between the Q values at timestep $t$ and the Bellman update target estimated using the reward $r_t$ and the Q values at timestep $t+1$, thus minimizing the *one-step* temporal difference. Formally, it can be expressed by the equation below.
$$
    J(\theta^{Q}) = \mathbb{E}_{(s,a,r,s') \sim \mathcal{D}} \big[ (Q(s, a) - y)^2 \big],
$$
with the Bellman update target $y = r + \gamma \, Q^{'}(s', a')$, where $a' \sim \mu^{'}(s')$, and the replay buffer $\mathcal{D}$.

* `losses/actor_loss`: implemented as `-qf1(data.observations, actor(data.observations)).mean()`; it is the *negative* average Q values calculated based on the 1) observations and the 2) actions computed by the actor based on these observations. By minimizing `actor_loss`, the optimizer updates the actors parameter using the following gradient (Lillicrap et al., 2016, Algorithm 1)[^1]:

$$ \nabla_{\theta^{\mu}} J \approx  \frac{1}{N}\sum_i\left.\left.\nabla_{a} Q\left(s, a \mid \theta^{Q}\right)\right|_{s=s_{i}, a=\mu\left(s_{i}\right)} \nabla_{\theta^{\mu}} \mu\left(s \mid \theta^{\mu}\right)\right|_{s_{i}} $$

* `losses/qf1_values`: implemented as `qf1(data.observations, data.actions).view(-1)`, it is the average Q values of the sampled data in the replay buffer; useful when gauging if under or over estimation happens.


### Implementation details

Our [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) is based on the [`OurDDPG.py`](https://github.com/sfujim/TD3/blob/master/OurDDPG.py) from :material-github: [sfujim/TD3](https://github.com/sfujim/TD3), which presents the the following implementation difference from (Lillicrap et al., 2016)[^1]:

1. [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) uses a gaussian exploration noise $\mathcal{N}(0, 0.1)$, while (Lillicrap et al., 2016)[^1] uses Ornstein-Uhlenbeck process with $\theta=0.15$ and $\sigma=0.2$.

1. [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) runs the experiments using the `openai/gym` MuJoCo environments, while (Lillicrap et al., 2016)[^1] uses their proprietary MuJoCo environments.

1. [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) uses the following architecture:
    ```python
    class QNetwork(nn.Module):
        def __init__(self, env):
            super(QNetwork, self).__init__()
            self.fc1 = nn.Linear(np.array(env.single_observation_space.shape).prod() + np.prod(env.single_action_space.shape), 256)
            self.fc2 = nn.Linear(256, 256)
            self.fc3 = nn.Linear(256, 1)

        def forward(self, x, a):
            x = torch.cat([x, a], 1)
            x = F.relu(self.fc1(x))
            x = F.relu(self.fc2(x))
            x = self.fc3(x)
            return x


    class Actor(nn.Module):
        def __init__(self, env):
            super(Actor, self).__init__()
            self.fc1 = nn.Linear(np.array(env.single_observation_space.shape).prod(), 256)
            self.fc2 = nn.Linear(256, 256)
            self.fc_mu = nn.Linear(256, np.prod(env.single_action_space.shape))

        def forward(self, x):
            x = F.relu(self.fc1(x))
            x = F.relu(self.fc2(x))
            return torch.tanh(self.fc_mu(x))
    ```
    while (Lillicrap et al., 2016, see Appendix 7 EXPERIMENT DETAILS)[^1] uses the following architecture (difference highlighted):

    ```python hl_lines="4-6 9-11 19-21"
    class QNetwork(nn.Module):
        def __init__(self, env):
            super(QNetwork, self).__init__()
            self.fc1 = nn.Linear(np.array(env.single_observation_space.shape).prod(), 400)
            self.fc2 = nn.Linear(400 + np.prod(env.single_action_space.shape), 300)
            self.fc3 = nn.Linear(300, 1)

        def forward(self, x, a):
            x = F.relu(self.fc1(x))
            x = torch.cat([x, a], 1)
            x = F.relu(self.fc2(x))
            x = self.fc3(x)
            return x


    class Actor(nn.Module):
        def __init__(self, env):
            super(Actor, self).__init__()
            self.fc1 = nn.Linear(np.array(env.single_observation_space.shape).prod(), 400)
            self.fc2 = nn.Linear(400, 300)
            self.fc_mu = nn.Linear(300, np.prod(env.single_action_space.shape))

        def forward(self, x):
            x = F.relu(self.fc1(x))
            x = F.relu(self.fc2(x))
            return torch.tanh(self.fc_mu(x))
    ```

1. [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) uses the following learning rates:

    ```python
    q_optimizer = optim.Adam(list(qf1.parameters()), lr=3e-4)
    actor_optimizer = optim.Adam(list(actor.parameters()), lr=3e-4)
    ```
    while (Lillicrap et al., 2016, see Appendix 7 EXPERIMENT DETAILS)[^1] uses the following learning rates:

    ```python
    q_optimizer = optim.Adam(list(qf1.parameters()), lr=1e-4)
    actor_optimizer = optim.Adam(list(actor.parameters()), lr=1e-3)
    ```

1. [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) uses `--batch-size=256 --tau=0.005`, while (Lillicrap et al., 2016, see Appendix 7 EXPERIMENT DETAILS)[^1] uses `--batch-size=64 --tau=0.001`

1. [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py)  also adds support for handling continuous environments where the lower and higher bounds of the action space are not $[-1,1]$, or are asymmetric.
The case where the bounds are not $[-1,1]$ is handled in [`DDPG.py`](https://github.com/sfujim/TD3/blob/385b33ac7de4767bab17eb02ade4a268d3e4e24f/DDPG.py#L15) (Fujimoto et al., 2018)[^2] as follows:
```python
class Actor(nn.Module):

    ...

	def forward(self, state):
		a = F.relu(self.l1(state))
		a = F.relu(self.l2(a))
		return self.max_action * torch.tanh(self.l3(a)) # Scale from [-1,1] to [-action_high, action_high]
```
 On the other hand, in [`CleanRL's ddpg_continuous_action.py`](https://github.com/dosssman/cleanrl/blob/10b606e7bd9bd1b06e455e8ef542df2b7699a20c/cleanrl/ddpg_continuous_action.py#L98), the mean and the scale of the the action space are computed as `action_bias` and `action_scale` respectively.
 Those scalars are in turn used to scale the output of a `tanh` activation function in the actor to the original action space range:
```python
class Actor(nn.Module):
    def __init__(self, env):
        ...
        # action rescaling
        self.register_buffer("action_scale", torch.FloatTensor((env.action_space.high - env.action_space.low) / 2.0))
        self.register_buffer("action_bias", torch.FloatTensor((env.action_space.high + env.action_space.low) / 2.0))

    def forward(self, x):
        x = F.relu(self.fc1(x))
        x = F.relu(self.fc2(x))
        x = torch.tanh(self.fc_mu(x))
        return x * self.action_scale + self.action_bias # Scale from [-1,1] to [-action_low, action_high]
```

Additionally, when drawing exploration noise that is added to the actions produced by the actor, [`CleanRL's ddpg_continuous_action.py`](https://github.com/dosssman/cleanrl/blob/10b606e7bd9bd1b06e455e8ef542df2b7699a20c/cleanrl/ddpg_continuous_action.py#L175) centers the distribution the sampled from at `action_bias`, and the scale of the distribution is set to `action_scale * exploration_noise`.

???+ info

    Note that `Humanoid-v2`, `InvertedPendulum-v2`, `Pusher-v2` have action space bounds that are not the standard `[-1, 1]`. See below.
    
    ```
    Ant-v2 Observation space: Box(-inf, inf, (111,), float64) Action space: Box(-1.0, 1.0, (8,), float32)
    HalfCheetah-v2 Observation space: Box(-inf, inf, (17,), float64) Action space: Box(-1.0, 1.0, (6,), float32)
    Hopper-v2 Observation space: Box(-inf, inf, (11,), float64) Action space: Box(-1.0, 1.0, (3,), float32)
    Humanoid-v2 Observation space: Box(-inf, inf, (376,), float64) Action space: Box(-0.4, 0.4, (17,), float32)
    InvertedDoublePendulum-v2 Observation space: Box(-inf, inf, (11,), float64) Action space: Box(-1.0, 1.0, (1,), float32)
    InvertedPendulum-v2 Observation space: Box(-inf, inf, (4,), float64) Action space: Box(-3.0, 3.0, (1,), float32)
    Pusher-v2 Observation space: Box(-inf, inf, (23,), float64) Action space: Box(-2.0, 2.0, (7,), float32)
    Reacher-v2 Observation space: Box(-inf, inf, (11,), float64) Action space: Box(-1.0, 1.0, (2,), float32)
    Swimmer-v2 Observation space: Box(-inf, inf, (8,), float64) Action space: Box(-1.0, 1.0, (2,), float32)
    Walker2d-v2 Observation space: Box(-inf, inf, (17,), float64) Action space: Box(-1.0, 1.0, (6,), float32)
    ```


### Experiment results

To run benchmark experiments, see :material-github: [benchmark/ddpg.sh](https://github.com/vwxyzjn/cleanrl/blob/master/benchmark/ddpg.sh). Specifically, execute the following command:

<script src="https://emgithub.com/embed.js?target=https%3A%2F%2Fgithub.com%2Fvwxyzjn%2Fcleanrl%2Fblob%2F2e2dc9c6ede5e5e5df3eaea73c458bb9a83507d2%2Fbenchmark%2Fddpg.sh%23L1-L7&style=github&showBorder=on&showLineNumbers=on&showFileMeta=on&showCopy=on"></script>

Below are the average episodic returns for [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) (3 random seeds). To ensure the quality of the implementation, we compared the results against (Fujimoto et al., 2018)[^2].

| Environment      | [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) | [`OurDDPG.py`](https://github.com/sfujim/TD3/blob/master/OurDDPG.py) (Fujimoto et al., 2018, Table 1)[^2]  | [`DDPG.py`](https://github.com/sfujim/TD3/blob/master/DDPG.py) using settings from (Lillicrap et al., 2016)[^1] in (Fujimoto et al., 2018, Table 1)[^2]    |
| ----------- | ----------- | ----------- | ----------- |
| HalfCheetah      | 9382.32 ± 1395.52      |8577.29  | 3305.60|
| Walker2d   | 1598.35 ± 862.66     |  3098.11 | 1843.85 |
| Hopper   | 1313.43 ± 684.46         |  1860.02 | 2020.46 |
| Humanoid |  897.74 ± 281.87      |  not available | 
| Pusher |  -34.45 ± 4.47      |  not available | 
| InvertedPendulum |    645.67 ± 270.31    | 1000.00 ± 0.00  | 


???+ info

    Note that [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) uses gym MuJoCo v2 environments while [`OurDDPG.py`](https://github.com/sfujim/TD3/blob/master/OurDDPG.py) (Fujimoto et al., 2018)[^2] uses the gym MuJoCo v1 environments. According to the :material-github: [openai/gym#834](https://github.com/openai/gym/pull/834), gym MuJoCo v2 environments should be equivalent to the gym MuJoCo v1 environments.

    Also note the performance of our `ddpg_continuous_action.py` seems to be worse than the reference implementation on Walker2d and Hopper. This is likely due to :material-github: [openai/gym#938](https://github.com/openai/baselines/issues/938). We would have a hard time reproducing gym MuJoCo v1 environments because they have been long deprecated.

    One other thing could cause the performance difference: the original code reported the average episodic return using determinisitc evaluation (i.e., without exploration noise), see [`sfujim/TD3/main.py#L15-L32`](https://github.com/sfujim/TD3/blob/385b33ac7de4767bab17eb02ade4a268d3e4e24f/main.py#L15-L32), whereas we reported the episodic return during training and the policy gets updated between environments steps.

Learning curves:

<div class="grid-container">
<img src="../ddpg/HalfCheetah-v2.png">

<img src="../ddpg/Walker2d-v2.png">

<img src="../ddpg/Hopper-v2.png">

<img src="../ddpg/Humanoid-v2.png">

<img src="../ddpg/Pusher-v2.png">

<img src="../ddpg/InvertedPendulum-v2.png">
</div>



## `ddpg_continuous_action_jax.py`

The [ddpg_continuous_action_jax.py](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action_jax.py) has the following features:

* Uses [Jax](https://github.com/google/jax), [Flax](https://github.com/google/flax), and [Optax](https://github.com/deepmind/optax) instead of `torch`.  [ddpg_continuous_action_jax.py](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action_jax.py) is roughly 2.5-4x faster than  [ddpg_continuous_action.py](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py)
* For continuous action space
* Works with the `Box` observation space of low-level features
* Works with the `Box` (continuous) action space

### Usage

```bash
poetry install -E "mujoco jax"
poetry run pip install --upgrade "jax[cuda]==0.3.14" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
poetry run python -c "import mujoco_py"
python cleanrl/ddpg_continuous_action_jax.py --help
poetry install -E mujoco # only works in Linux
python cleanrl/ddpg_continuous_action_jax.py --env-id Hopper-v3
```

### Explanation of the logged metrics

See [related docs](/rl-algorithms/ddpg/#explanation-of-the-logged-metrics) for `ddpg_continuous_action.py`.


### Implementation details

See [related docs](/rl-algorithms/ddpg/#implementation-details) for `ddpg_continuous_action.py`.


### Experiment results

To run benchmark experiments, see :material-github: [benchmark/ddpg.sh](https://github.com/vwxyzjn/cleanrl/blob/master/benchmark/ddpg.sh). Specifically, execute the following command:

<script src="https://emgithub.com/embed.js?target=https%3A%2F%2Fgithub.com%2Fvwxyzjn%2Fcleanrl%2Fblob%2F5f0ed8443904c15cfd6d0d61cb9813b475263e60%2Fbenchmark%2Fddpg.sh%23L9-L16&style=github&showBorder=on&showLineNumbers=on&showFileMeta=on&showCopy=on"></script>

Below are the average episodic returns for [`ddpg_continuous_action_jax.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action_jax.py) (3 random seeds). To ensure the quality of the implementation, we compared the results against (Fujimoto et al., 2018)[^2].

| Environment      | [`ddpg_continuous_action_jax.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action_jax.py) | [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py)  | [`OurDDPG.py`](https://github.com/sfujim/TD3/blob/master/OurDDPG.py) (Fujimoto et al., 2018, Table 1)[^2]    |
| ----------- | ----------- | ----------- | ----------- |
| HalfCheetah |  9910.53 ± 673.49     | 9382.32 ± 1395.52      |8577.29  |
| Walker2d |  1397.60 ± 677.12  | 1598.35 ± 862     |  3098.11 | 
| Hopper |  1603.5 ± 727.281  | 1313.43 ± 684.46         |  1860.02 | 


???+ info

    Note that we ran the [`ddpg_continuous_action_jax.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action_jax.py) experiments with RTX 3060 Ti (~810 SPS) and [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) experiments with RTX 2060 (~241 SPS). Using RTX 3060 Ti w/ [`ddpg_continuous_action.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action.py) brings the SPS from 241 to 325, according to [this report](https://wandb.ai/costa-huang/cleanRL/reports/Torch-DDPG-2060-vs-3060ti---VmlldzoyMzA1NDYy) meaning that under the same hardware, [`ddpg_continuous_action_jax.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action_jax.py) would be **roughly 810/241=2.5x faster**.  However, because of the overhead of `--capture-video` that both scripts suffer, we suspect [`ddpg_continuous_action_jax.py`](https://github.com/vwxyzjn/cleanrl/blob/master/cleanrl/ddpg_continuous_action_jax.py) would be 3x-4x faster when `--capture-video` is disabled.


Learning curves:

<div class="grid-container">
<img src="../ddpg-jax/HalfCheetah-v2.png">
<img src="../ddpg-jax/HalfCheetah-v2-time.png">

<img src="../ddpg-jax/Walker2d-v2.png">
<img src="../ddpg-jax/Walker2d-v2-time.png">

<img src="../ddpg-jax/Hopper-v2.png">
<img src="../ddpg-jax/Hopper-v2-time.png">
</div>



Tracked experiments and game play videos:

<iframe src="https://wandb.ai/openrlbenchmark/openrlbenchmark/reports/MuJoCo-CleanRL-s-DDPG-JAX--VmlldzoyMjQxMjE2" style="width:100%; height:500px" title="MuJoCo: CleanRL's DDPG + JAX"></iframe>


[^1]:Lillicrap, T.P., Hunt, J.J., Pritzel, A., Heess, N.M., Erez, T., Tassa, Y., Silver, D., & Wierstra, D. (2016). Continuous control with deep reinforcement learning. CoRR, abs/1509.02971. https://arxiv.org/abs/1509.02971

[^2]:Fujimoto, S., Hoof, H.V., & Meger, D. (2018). Addressing Function Approximation Error in Actor-Critic Methods. ArXiv, abs/1802.09477. https://arxiv.org/abs/1802.09477
