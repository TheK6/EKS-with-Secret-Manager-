# EKS-com-Secret-Manager
 
 *Crie uma cluster EKS com um servidor NGINX conectado ao AWS Secret Manager com o Kubernetes Store CSI Driver*

## 1 - Comece Criando o cluster EKS (aqui feito manualmente)

 ***Você vai precisar de um usuário com permissão de Admin.***

* Crie uma VPC com IPs suficientes para os nodes.
* Crie 6 subnets - 3 privadas e 3 publicas. Coloque a seguinte TAG nas subnets

  ``` 
  kubernetes.io/cluster/<cluster_name>
  ``` 
  
* Atribua o valor **shared** para a TAG. 
* Crie 2 route tables 
* Crie um internet gateway - conecte a sua VPC
* Crie um NAT Gateway em uma das suas subnetes publicas.
* Configure as rotas das Tables Routes
* Crie um Cluster
* Crie os nodes do cluster
* Verifique que você consegue acessar o cluster 

        kubectl get svc 
        
* se a conexão funcionar vai retornar um aviso assim:


![alt text](https://i.imgur.com/1qI1sSz.png)


## 2  - Crie um segredo no Secret Manager

* Go to AWS Secret Manager 
* **Create Secret**
* Selecione o tipo de segredo (ex: Other Type of secrets)
* Insira um **Secret key/value** (ex: *MY_API_TOKEN* e *osegredo*)
* Next
* Insira um **secret name** -- Ele vai ser usado como referência nos documentos (*ex: prod/service/token*) 
* Não vamos dar permissões por aqui, e sim usando um **Role**. 
* Next
* **Store**
* Abra o segredo e olhe o **Secret ARN** ele vai ser importante, então tenha de fácil acesso

## 3 - Crie um IAM OIDC provider para o EKS

* Vá para a página do EKS e selecione o seu cluster
* Selecine os nodes
* Na aba **Configurations** e desça até a área de **Details**
* Procure os dados de ***OpenID Connect provider URL*** e copie o link 
* Vá para a página de AWS IAM
* No menu lateral esquerdo selecione **Identity providers**
* Add Providers
* Selecione **OpenID Connect**
* Cole o URL que você copiou na página do EKS no campo **Provider URL** (*Cuidado para não duplicar o https://*)
* Edit URL -- Um thumbprint vai ser criado
* No campo Audience coloque a ID do Cliente (*ex: sts.amazonaws.com*) -- Isso vai ser atualizado posteriormente7
* Salve

## 4 - Crie uma IAM Policy para ler o segredo

* Volte para o dashbord da AWS IAM
* No menu lateral selecione **Policies**
* **Create Policy**
* Selecione a aba JSON
* Copie o exemplo abaixo e cole na editor JSON
      
``` 
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "<use o ARN do seu segredo. Vide ultimo passo do item 2>" 
        }
    ]
}
```
* **Next:Tags**
* **Next: Review**
* Insira um nome único no campo **Name**. (*ex: APITokenReadAccess*) -- O nome é importante e vai ser referenciado mais tarde
* **Create Policy**

## 5 - Crie um IAM Role para a Conta de Serviço Kubernetes

* Volte para o dashbord da AWS IAM
* No menu lateral selecione **Roles**
* **Create Roles**
* Selecione **Web Identity**
* No campo **Identity Provider** selecione o Identity Provider criado anteriormente (Item 3)
* No campo **Audience** coloque o mesmo que foi utilizado no item 3 (*ex: sts.amazonaws.com*)
* **Next: Permissions**
* Filtre as Policies existente por **Policy Type** e selecione **Custom managed**
* Selecione a policy *APITokenReadAccess* criada anteriormente
* **Next: Tags**
* **Next: Review**
* No campo **Role Name** insira o nome da Role (*ex: api-token-access)
* **Create role**
* Na página principal de Roles, clique no seu role recem criado. 
* Vá na aba **Trust Relationships** 
* **Edit trust Relationship**
* No editor do **Policy Document** desça até a última parte do text
* Na parte *"StringEquals"*, no fim da linha, troque a palavra ***aud*** pela palavra ***sub***
* E onde se encontra a **audience** colocada anteriormente, coloque a service account no ambiente de produção com o serviço aprensentado:

        "system:serviceaccount:production:nginx"
        
* Como no exemplo:

![Edit Trust Relationship](https://i.imgur.com/g1lBsBR.png)

* **Update Trust Policy**

# 6 - Associe o IAM role com o Kubernetes Account

* Crie uma pasta **NGINX** para colocar todos os arquivos Kubernetes (ou faça um pull deste repositório)
* Crie um arquivo para criar a namespace *production* (*0-namespace.yaml*)
* Precisa ser o mesmo namespace que você colocou no IAM role:

![Criando a namespace production](https://i.imgur.com/K8Wb8u8.png)

* Crie um arquivo para a Kubernetes Service Account (1-service-account.yaml)
* Coloque o namespace também e mais importante, coloque uma annotation para permitir essa conta usar o role criado
* Copie o ARN do role criado na AWS e cole na annotation:

![Service Account com o IAM role](https://i.imgur.com/ncohEHK.png)

* Agora vá ao seu terminal e faça deploy da pasta para criar o namespace e o service account:

        kubectl apply -f nginx

* O sistema deve retornar os dois itens criados:

![Apply namespace and service account](https://i.imgur.com/8uY9LOh.png)

* Se você listar os namespaces, vai mostrar um criado agora:

        kubectl get ns
    
* O sistema deve retornar algo parecido:

![lista de namespaces](https://i.imgur.com/BC9GUIP.png)

# 7 - Instale o **Kubernetes Secrets Store CSI Driver**
*Ele integra o Secret Manager com o Kubernetes através de uma Container Storage Interface Volume*

* Isso será feito com arquivos yaml (que estão nesse respositório)
* Primeiro vamos criar duas definições de recursos customisadas 
* No diretório onde está sua pasta **NGINX**
* Crie uma pasta *secrets-store-csi-driver* (ou baixe do repositório)
* Copie o arquivo *secrets-store-csi-driver/0-secretproviderclasses-crd.yaml* (ou baixe)
* Na linha linha 12 tem o **Secret Provider Class**

![Secret Provider Class](https://i.imgur.com/3gqmEIp.png)

* Vamos criar o outro arquivo 
* Copie o arquivo *secrets-store-csi-driver/1-secretproviderclasspodstatuses-crd.yaml* (ou baixe)
* Na linha 12 você verá o **Secret Provider Class Pod Status**

![Secret Provider Class Pod Status](https://i.imgur.com/c49PgSs.png)

* Faça deploy no terminal

        kubectl apply -f secrets-store-csi-driver

* O output:

![](https://i.imgur.com/sSsoAMc.png)

* Vamos ver se os CRDs foram criados:

        kubectl get crds

* O output:

![](https://i.imgur.com/Qvz396x.png)


 ### Vamos finalizar o Deployment

* Copie o arquivo *2-service-account.yaml*

![Second service account](https://i.imgur.com/AASobCG.png)

* E agora o role para a cluster:
* Copie o arquivo 3-cluster-role.yaml
* O próximo aquivo é para associar o service account ao role:
* Copie o arquivo 4-cluster-role-binding.yaml para o diretório

![](https://i.imgur.com/XRlTYqj.png)

* Agora pecisamos rodar esse Secret Store CSI driver em cada node, então vamos criar um deamonset para fazer isso:
* Copie o aquivo 5-daemonset.yaml para o seu diretório
* E finalmente vamos criar o CSI driver:
* copie o arquivo 6-csi-driver.yaml

![](https://i.imgur.com/3tyl40F.png)

* Vá para o terminal e faça o deploy

        kubectl apply -f secrets-store-csi-driver
        
* Um output bem sucedido:

![](https://i.imgur.com/Bkfiv9l.png)

* Você pode olhar os logs pra ver se não tem nenhum erro:

        kubectl logs -n kube-system -f -l app=secrets-store-csi-driver


## 8 - Instale o AWS Secrets & Configuration Provider

* O AWS provider para a Secret Store CSI Driver permite criar segredos guardados no Secret Manager e parâmetros criados no Parameter Store, aparecerem como arquivos montados nos pods do Kubernetes ou usá-los como variáveis de ambiente. É possível fazer usando **Helm**, mas por aqui vamos fazer usando arquivos yaml. 

* Crie uma terceira pasta: ***aws-provider-installer***
* Entre no diretório e copie o aquivo para criar um service account: *0-service-account.yaml*

![](https://i.imgur.com/lNcfmXr.png)

* Agora vamos criar o cluster role:
* copie o arquivo *1-cluster-role.yaml*

![](https://i.imgur.com/7cjiXSg.png)

* Agora o cluster role binding.
* Copie o arquivo *2-cluster-role-binding.yaml*

![](https://i.imgur.com/1IymNS9.png)

* E agora o deamonset
* Copie o arquivo *3-daemonset.yaml*
* E agora vamos fazer o deploy desses arquivos:

      kubectl apply -f aws-provider-installer
      
* E o output:

![](https://i.imgur.com/NwP7MOs.png)

* Agora olhe os pods rodando:

        kubectl get pods -n kube-system
        
![](https://i.imgur.com/kYMSgrC.png)

* O CSI Secret Store Provider está funcionando. 

## Crie uma Secret Provider Class

*Esse objeto vai mapear os segredos no Secrets Manager com o K8 provider. 

* Volte para o diretório **NGINX**
* Copie o arquivo *2-secret-provider-class.yaml*

![](https://i.imgur.com/hjj34Qi.png)

* É uma *Secret Provider Class*
* Deve ser colocada na mesma namespace criada (*ex: production*)
* Na área de parâmetros precisamos definir o nome do segredo (*ex: prod/service/token*)
* Podemos usar o Secret Manager ou o SSM parâmeter (*Aqui usando o secretsmanager*)
* Temos a opção de criar um apelido (ALIAS) para o segredo (*ex: secret-token*) 
* Já que também queremos criar uma variável de ambiente, precisamos criar um segredo no Kubernetes. *api-token* vai ser o nome do segredo no K8. 
* **SECRET_TOKEN** é apenas uma chave dentro do sistema 
* Vamos fazer o deploy:

        kubectl apply -f nginx
        
![](https://i.imgur.com/ryKooX6.png)

## 9 - Hora de Fazer o teste com o NGINX

*Vamos criar o último objeto*

* No diretório do NGINX
* Copie o arquivo *3-deployment.yaml*
* É um deployment simples baseado no servidor NGINX reverse proxy. Ele está sendo usado como um placeholder image. 
* Para montar o secredo como um arquivo precisamos criar um volume usando a keyword do CSI e direcionar à classe provider 
* Depois vamos usar o volume e montar o *my-api-token* > */mnt/api-token*
* Vamos expor esse segredo como uma variável de ambiente e chama-la **API_TOKEN** e pegar o valor do K8 Secret api-token (foi criada pelo controller)

![](https://i.imgur.com/TP75heZ.png)

* Vamos fazer o deploy:

        kubectl apply -f nginx
        
 ![](https://i.imgur.com/Lrx5ORH.png)
 
 * Pegue os segredos que estão no EKS:
 
        kubectl get secrets -n production
        
 ![](https://i.imgur.com/kG0r7Ob.png)
 
 * Agora vamos entrar em um pod e imprimir o conteudo 
 
        kubectl get pods -n production
        
        kubectl -n production exec -it nginx-<id> -- bash
        
![](https://i.imgur.com/68FgaA9.png)

### Vamos ver o segredo!

* Dentro do pod, vamos dar um *cat* para ver o conteúdo. Assim vamos ver o segredo

        cat /mnt/api-token/secret-token

![](https://i.imgur.com/1n0VFhy.png)

* O segredo que você criou vai estar logo após o **API_TOKEN**

* Agora para vermos se temos o segredo como uma variável de ambiente 

        echo $API_TOKEN

![](https://i.imgur.com/WR0zDIu.png)

# XABLAU

***Fonte*** 

[AWS EKS & Secrets Manager (File & Env | Kubernetes | Secrets Store CSI Driver | K8s)](https://www.youtube.com/watch?v=Rmgo6vCytsg&t=613s)


