# Kubernetes `kubectl` auto-completion
source: [aliases and completion `kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-shell-autocompletion)
- install bash completion
```bash
sudo apt install bash-completion
```
- install `kubectl` completion and make an short alias
```bash
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc
source ~/.bashrc
```
