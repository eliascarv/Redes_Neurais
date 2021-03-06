using Flux
using Flux: train!, throttle, @epochs, onecold
using Flux: batch, unsqueeze, onehotbatch
using Flux.Losses: logitcrossentropy
using Flux.Data: DataLoader
using Flux.Data.MNIST
using Statistics, Random
using BSON: @save

Random.seed!(2)

#Carregando os dados de treino
images_train = MNIST.images(:train)
labels_train = MNIST.labels(:train)

#Carregando os dados de teste
images_test = MNIST.images(:test)
labels_test = MNIST.labels(:test)

# Função para converter o vetor de imagens em um vetor de matrizes
preprocess(img) = Float32.(img)

# Preparando os tensors
xtrain_tensor = batch(preprocess.(images_train))
xtest_tensor = batch(preprocess.(images_test))

# Adicionando a camada de channel
xtrain = unsqueeze(xtrain_tensor, 3)
xtest = unsqueeze(xtest_tensor, 3)

# Ou em apenas um comando:
# xtrain = cat(preprocess.(images_train)..., dims = 4)
# xtest = cat(preprocess.(images_test)..., dims = 4)

# Convertendo o vetor de labels em um vetor onehot
ytrain = onehotbatch(labels_train, 0:9)
ytest = onehotbatch(labels_test, 0:9)

# Declarando o modelo
model = Chain(
    Conv((5, 5), 1 => 32, relu),
    Conv((5, 5), 32 => 32, relu),
    MaxPool((2, 2)),
    Dropout(0.25),

    Conv((3, 3), 32 => 64, relu),
    Conv((3, 3), 64 => 64, relu),
    MaxPool((2, 2), stride = (2, 2)),
    Dropout(0.25),

    flatten,
    Dense(576, 256, relu),
    Dropout(0.5),
    Dense(256, 10)
)

# Com SamePad fica 3136 no lugar de 576

# Função de perda para o treinamento do modelo
loss(x, y) = logitcrossentropy(model(x), y)
# Prâmetros do modelo
ps = params(model)
# Carregando os dados de treino e teste
train = DataLoader((xtrain, ytrain), batchsize = 200, shuffle = true)
test = DataLoader((xtest, ytest), batchsize = 200)
# Escolhendo o otimizador
opt = RMSProp()

# Primiero treinamento (mais demorado)
train!(loss, ps, train, opt)

# Função para avaliar a loss do modelo
function eval_loss(loader)
    loss_sum = 0.0
    batch_tot = 0
    for batch in loader
        x, y = batch
        loss_sum += loss(x, y) * size(x)[end]
        batch_tot += size(x)[end]
    end
    return round(loss_sum/batch_tot, digits = 4)
end

# Função para exibir a loss do modelo
evalcb() = println("Train loss: $(eval_loss(train)) | Test loss: $(eval_loss(test))")
throttle_cb = throttle(evalcb, 15) # Exiba a loss a cada 15 segundos

# Treinando o modelo com 10 épocas (qnt de treinos)
@epochs 10 train!(loss, ps, train, opt, cb = throttle_cb)

# Função para medir a acurácia do modelo
accuracy(ŷ, y) = mean(onecold(ŷ) .== onecold(y)) 
# ŷtrin = model(xtrain)
# accuracy(ŷtrain, ytrain)
ŷtest = model(xtest)
accuracy(ŷtest, ytest)

# Macro para salvar o modelo já treinado no formato BSON
@save "MNIST_Conv_model.bson" model