# Petclinic — Angular WEB + Spring REST API

Petclinic은 동물병원에서 **보호자, 반려동물, 방문 기록, 수의사**를 관리하는 예제 애플리케이션입니다. 이 저장소에는 EKS 환경에서 사용하도록 수정했던 두 앱의 **소스 코드**가 들어 있습니다. AWS 계정 없이도 로컬에서 두 앱을 함께 실행할 수 있습니다.

**배포 상태:** 이전 EKS·RDS 배포는 롤백했습니다. 이 저장소의 `main`에 push해도 AWS 리소스가 생성되거나 서비스가 재배포되지 않습니다. Terraform, Kubernetes 매니페스트, Dockerfile, Docker Compose, 운영 자격 증명은 포함하지 않습니다.

## 앱 실행·빌드 기준: Ubuntu 24.04 LTS (x86_64)

이 저장소에서 WEB은 **Node.js 24.x + npm**, WAS는 **JDK 21 + Maven Wrapper**로 실행합니다. [GitHub Actions](.github/workflows/ubuntu-24.04.yml)도 `ubuntu-24.04`로 고정했습니다. 앱 소스 검증용 CI이며 AWS 인증, 이미지 push, Terraform apply, EKS 배포는 하지 않습니다.

아래는 처음 설정하는 Ubuntu 호스트에서 **저장소를 clone한 뒤 루트에서** 실행하는 예입니다. 이미 Node 24와 JDK 21이 설치되어 있다면 설치 단계는 건너뛰세요. Ubuntu 기본 `nodejs` 패키지만 설치하면 이 프로젝트가 요구하는 24.x가 아닐 수 있습니다.

```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk git curl ca-certificates unzip python3
# JDK가 여러 개 설치되어 있어도 이 셸에서는 Ubuntu의 JDK 21을 선택합니다.
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
java -version

# nvm이 없는 경우에만 사용자 홈에 설치합니다. 시스템 Node는 교체하지 않습니다.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  git clone --depth 1 --branch v0.40.3 https://github.com/nvm-sh/nvm.git "$NVM_DIR"
fi
. "$NVM_DIR/nvm.sh"
(cd petclinic-angular && nvm install)
nvm use 24
node --version   # v24.x
npm --version
```

**실행:** 아래 「처음 실행하기」처럼 터미널 두 개에서 REST와 WEB을 시작합니다. 새 셸에서 Node가 다른 버전이면 `. "$HOME/.nvm/nvm.sh"` 후 `nvm use 24`를 실행하세요. **연동 검사:** `npm ci`와 `./mvnw package`를 각각 앱 폴더에서 완료한 뒤, 서버가 떠 있지 않은 상태에서 저장소 루트의 `bash scripts/smoke-local.sh`를 실행합니다. [검사 스크립트](scripts/smoke-local.sh)는 두 앱을 로컬에서 기동하고, REST readiness와 Angular 프록시를 거친 H2 보호자 조회까지 확인한 뒤 종료합니다.

## 과거 EKS 배포 기록 — 현재 Ubuntu 앱 기준과 별개

**당시 구성은 비공개 EKS + IAM Access Entry + VPC CNI용 IRSA + `kubectl apply`였습니다. Helm은 사용하지 않았습니다.** 아래는 롤백 전에 사용한 구성입니다. 현재 실행 중인 클러스터나 이 앱 저장소만으로 재배포하는 절차를 뜻하지 않습니다. 로컬에서 앱만 실행할 때는 아래 **「처음 실행하기」**부터 보면 됩니다.

### 클러스터, 노드와 서브넷

| 항목 | 배포 당시 값 | 운영상 의미 |
|---|---|---|
| 클러스터 | 서울 `ap-northeast-2`, `petclinic-prod`, Kubernetes `1.36`, `STANDARD` 지원 | API endpoint는 `private=true`, `public=false`. 웹 도메인이 공개돼도 인터넷에서 `kubectl`로 직접 접속할 수 없었습니다. |
| 워커 | 관리형 노드 그룹 `petclinic-prod-app` 하나, AMI `AL2023_x86_64_STANDARD`, 온디맨드 `t3.medium`, min/desired/max 모두 `2` | 노드 업데이트는 `max_unavailable=1`. 노드 수는 부하에 따라 자동 증가하지 않았습니다. 루트 볼륨은 암호화 gp3 20 GiB, IMDSv2 필수·hop limit 1입니다. |
| 앱 서브넷 | 서울 2a `10.10.0.0/24`, 2c `10.10.1.0/24` | WEB과 WAS가 같은 앱망을 쓰되 별도 Pod로 실행됐습니다. 배포 당시 실측은 각 AZ에 WEB 1개·API 1개였습니다. 단일 노드 그룹이 항상 AZ당 한 노드를 보장하는 것은 아닙니다. |
| 관리·DB | 관리 EC2 `t3.micro`는 별도 VPC의 `10.20.0.0/27`(2a). RDS PostgreSQL 16.15 Multi-AZ는 `10.10.2.64/27`(2a), `10.10.2.96/27`(2c) DB 서브넷 그룹 | 관리 EC2에는 공개 IP·SSH 인바운드가 없었습니다. DB는 비공개이고 5432 인바운드는 클러스터 보안 그룹에서만 허용했습니다. Pod별 NetworkPolicy와는 다른 경계입니다. |

근거: [EKS·노드·관리 EC2 Terraform](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/infra/envs/aws-prod/eks-platform.tf) · [네트워크 모듈](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/infra/modules/aws-network/main.tf) · [RDS 구성](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/infra/envs/aws-prod/database.tf)

### OIDC·IRSA: 어떤 Pod가 AWS 권한을 받았나?

OIDC는 사이트 로그인이나 운영자의 `kubectl` 로그인을 위한 설정이 아니었습니다. **Pod 네트워크를 담당하는 `aws-node`만 EC2 네트워크 API를 호출하도록** 서비스 계정과 IAM 역할을 연결했습니다. 이 방식을 IRSA(IAM Roles for Service Accounts)라고 합니다.

1. 클러스터가 발급한 OIDC issuer URL을 IAM OIDC Provider로 등록하고, 대상(`aud`)을 `sts.amazonaws.com`으로 지정했습니다.
2. CNI 역할의 신뢰 정책은 해당 Provider를 신뢰하면서 `sub=system:serviceaccount:kube-system:aws-node`와 `aud=sts.amazonaws.com`을 **모두** 요구합니다. 이 토큰으로만 `sts:AssumeRoleWithWebIdentity`를 통해 임시 AWS 자격 증명을 받을 수 있습니다.
3. 역할에 `AmazonEKS_CNI_Policy`를 부여하고 EKS 관리형 애드온 `vpc-cni`의 `service_account_role_arn`에 연결했습니다. WEB·API에는 이 역할을 주지 않았습니다. **ECR 이미지 pull은 CNI 역할이 아니라 워커 노드 역할**의 `AmazonEC2ContainerRegistryPullOnly`로 처리했습니다.

즉, 이 OIDC 설정은 GitHub Actions OIDC나 EKS Pod Identity가 아닙니다. [OIDC Provider·역할 신뢰 조건·애드온 정의](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/infra/envs/aws-prod/eks-platform.tf)

### IAM과 Kubernetes RBAC: 누가 무엇을 할 수 있었나?

| 주체 | 인증·권한 | 범위 |
|---|---|---|
| 클러스터를 생성한 IAM 주체 | `authentication_mode="API"`, `bootstrap_cluster_creator_admin_permissions=true` | 최초 cluster-admin. 네임스페이스 생성과 초기 설정에 사용했습니다. |
| 관리 EC2의 인스턴스 역할 | AWS IAM에서 대상 클러스터 `eks:DescribeCluster`와 SSM 에이전트 채널 권한. 별도로 EKS `STANDARD` Access Entry에 `AmazonEKSEditPolicy` 연결 | **`petclinic` 네임스페이스만 Edit**. `DescribeCluster`만으로 Deployment를 수정할 수는 없습니다. Edit도 워크로드와 Secret에 영향을 주므로 신뢰된 운영자용입니다. |
| 제어면 / 워커 | 제어면 `AmazonEKSClusterPolicy`; 워커 `AmazonEKSWorkerNodePolicy` + ECR pull 정책 | 클러스터 및 노드 운영용입니다. 앱의 DB 관리자 권한이 아닙니다. |
| WEB·API Pod | `automountServiceAccountToken: false`; 앱 전용 IAM 역할이나 Kubernetes 권한 바인딩 없음 | Spring은 Kubernetes API 권한이 아니라 별도 PostgreSQL 앱 계정으로 DB에 접속합니다. |

**직접 만든 `Role`/`RoleBinding`/`ClusterRoleBinding` YAML은 없습니다.** 관리 역할의 권한은 `aws-auth` ConfigMap을 수동 편집하지 않고 EKS Access Entry와 **네임스페이스 범위 Access Policy**로 부여했습니다. `AmazonEKSEditPolicy`는 Kubernetes `Role` 객체가 아니라 EKS가 요청을 인가할 때 사용하는 정책입니다. 아래의 Pod Security `restricted`는 또 다른 장치로, *누가 배포할 수 있는지*가 아니라 *어떤 Pod 사양을 허용할지*를 검사합니다.

### kubectl: 비공개 API에 어떻게 접속했나?

**운영자 PC의 kubectl → 로컬 포트 → SSM 터널 → 관리 EC2 → VPC 피어링 → EKS private API:443** 순서입니다. 웹 사용자는 이 관리 경로를 거치지 않습니다. 관리 VPC의 `ssm`, `ssmmessages`, `eks`, `sts` 인터페이스 엔드포인트 중 `eks`는 AWS 관리 API용이며, Kubernetes API 서버 그 자체가 아닙니다.

아래는 **클러스터가 있을 때만** 쓸 수 있는 예시입니다. 터미널 A는 [인프라 보존 브랜치](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/tree/a306bdcf293ecba5cff81fcd6b32deabcb5db98b) 루트에서 시작합니다. AWS CLI v2, Session Manager 플러그인, 호환 `kubectl`, `jq`, 허가된 AWS 프로필이 필요합니다.

```bash
# 터미널 A: 실제 프로필과 SSM Online 상태인 관리 인스턴스 ID로 교체
export AWS_PROFILE='<운영자 프로필>' AWS_REGION=ap-northeast-2
export CLUSTER=petclinic-prod MANAGER_ID='<관리 EC2 인스턴스 ID>'
export TUNNEL_KUBECONFIG="$(mktemp -d)/kubeconfig"
bash deploy/eks-tunnel.sh
```

[터널 스크립트](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/deploy/eks-tunnel.sh)는 `aws eks update-kubeconfig`로 전용 파일을 만들고 기본 `127.0.0.1:18443`을 원격 API의 443으로 전달합니다. 접속 주소만 로컬로 바꾸고 `tls-server-name`은 실제 EKS 호스트로 유지하므로 인증서 검증을 끄지 않습니다. `kubectl` 인증 토큰은 **로컬 AWS CLI의 `eks get-token`**으로 얻습니다. SSM 접속에 성공해도 로컬 IAM 신원에 클러스터 권한이 없으면 `kubectl`은 거부됩니다.

```bash
# 터미널 B: A와 같은 AWS_PROFILE을 사용하고, A가 출력한 export KUBECONFIG=... 실행 후 확인
aws sts get-caller-identity
kubectl config current-context
kubectl get nodes -L topology.kubernetes.io/zone    # 노드 조회 권한이 있는 운영자
kubectl -n petclinic get deploy,svc,pods -o wide
```

**권한을 시험할 때는 신원을 구분하세요.** 관리 EC2에서 인스턴스 역할의 자격 증명과 그 역할용 kubeconfig로 실행한다면 `kubectl auth can-i create deployments -n petclinic`은 `yes`, `kubectl auth can-i create namespaces`는 `no`가 기대값입니다. 실제 배포 때는 AWS에서 정책 연결과 범위를 확인했지만 이 역할로 두 명령을 직접 실측하지는 않았습니다. PC의 관리자 신원으로 터널에서 얻은 결과를 관리 EC2의 권한 증거로 쓰면 안 됩니다.

### Helm 대신 무엇으로 배포했나?

**Helm chart, `values.yaml`, Helm release는 없었습니다.** VPC CNI도 Helm 설치가 아니라 Terraform의 `aws_eks_addon`으로 관리했습니다. 앱 배포 경로는 다음과 같습니다.

| 순서 | 실행 주체와 입력 | 생성·검증한 것 |
|---|---|---|
| 1. 인프라 | 운영자가 검토한 Terraform plan을 수동 적용 | EKS·IAM·ECR·RDS·대상 그룹·네트워크. [인프라 PR CI](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/.github/workflows/terraform-check.yml)는 포맷·검증·mock plan 테스트만 수행하고 운영에 배포하지 않습니다. |
| 2. 이미지 | [게시 스크립트](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/deploy/publish-release.sh)가 테스트한 WEB·API 이미지를 비공개 ECR에 push | `WEB_IMAGE`, `API_IMAGE`는 `latest`가 아니라 검증된 `@sha256:` digest입니다. |
| 3. DB 초기화 | [bootstrap.sh](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/deploy/k8s/bootstrap.sh)가 `petclinic` 네임스페이스에 `restricted` 정책을 걸고 단기 Job 실행 | PostgreSQL 스키마·제한된 앱 계정을 준비하고 Job을 지웁니다. 관리자 암호는 앱 Secret으로 남기지 않고, WAS는 별도의 `petclinic-db-app` Secret을 사용했습니다. |
| 4. 앱 배포 | [deploy.sh](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/deploy/k8s/deploy.sh)가 이미지 digest 2개와 `DB_HOST`를 `envsubst`로 [apps.yaml.in](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/deploy/k8s/apps.yaml.in)에 주입 후 `kubectl apply -f -` 실행 | `Deployment/web`, `Deployment/api`, `Service/web`, `Service/api` 생성. 각각 `kubectl rollout status`로 준비 완료를 기다렸습니다. |

### 트래픽, Pod 보안과 가용성

| 경로 | ALB → Kubernetes → 컨테이너 | 상태 판정 |
|---|---|---|
| `/` 등 화면 경로 | 내부 ALB → WEB `NodePort 30080` → Nginx `8080` | `/`가 준비되면 트래픽을 받습니다. |
| `/petclinic/api/*` | 내부 ALB → API `NodePort 30966` → Spring `9966` → RDS `5432` | readiness는 DB 연결을 포함하고, startup/liveness는 JVM 상태를 봅니다. 일시적인 DB 장애가 JVM 재시작으로 번지지 않게 했습니다. |

- 도메인 → CloudFront VPC Origin → 기존 내부 ALB 순서였습니다. **AWS Load Balancer Controller나 Kubernetes Ingress는 사용하지 않았습니다.** Terraform에서 노드 그룹의 ASG를 `instance` 타입 대상 그룹 2개에 연결했습니다. 두 Service는 `externalTrafficPolicy: Cluster`라서 등록된 노드가 다른 노드의 Ready Pod에도 전달할 수 있습니다. [ALB·대상 그룹·SG 규칙](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/blob/a306bdcf293ecba5cff81fcd6b32deabcb5db98b/infra/envs/aws-prod/application-edge.tf)
- WEB과 API는 각각 2 replicas, `RollingUpdate(maxUnavailable=0, maxSurge=1)`입니다. AZ별 `maxSkew=1`은 `DoNotSchedule`, 호스트별 분산은 `ScheduleAnyway`였습니다. HPA, Cluster Autoscaler, PDB는 설정하지 않았습니다.
- WEB은 UID 101, API는 UID 10001로 실행합니다. 모두 non-root, 읽기 전용 루트 파일시스템, `allowPrivilegeEscalation: false`, capabilities `drop: ALL`, seccomp `RuntimeDefault`입니다. CPU/메모리 요청→상한은 WEB `25m/32Mi → 250m/96Mi`, API `200m/384Mi → 1 CPU/768Mi`였습니다.

배포 당시 실제 확인한 것은 WEB·API 각각 `2/2` Ready, 두 대상 그룹 healthy, 도메인을 통한 테스트 데이터 등록·재조회·삭제입니다. 이는 **롤백 전 기록**이며 장애조치나 백업 복원까지 검증했다는 뜻은 아닙니다.

## 1. WEB과 WAS는 어떻게 나뉘나요?

| 구성 | 역할 | 로컬 주소 |
|---|---|---|
| [Angular WEB](petclinic-angular/) | 메뉴, 검색 결과, 등록·수정 폼을 브라우저에 표시합니다. DB에 직접 접속하지 않습니다. | `http://localhost:4200/` |
| [Spring REST API (WAS)](petclinic-rest/) | 브라우저의 요청을 검증하고 서비스·저장소 계층을 거쳐 DB에 읽고 씁니다. | `http://localhost:9966/petclinic/api/` |
| 데이터베이스 | 기본값은 예제 데이터가 들어 있는 메모리 H2입니다. 영구 저장이 필요하면 외부 PostgreSQL을 선택합니다. | API에서만 접근 |

예를 들어 **Add Owner**를 누르면 브라우저가 `POST /petclinic/api/owners`를 보냅니다. 로컬에서는 Angular 개발 서버의 [프록시 설정](petclinic-angular/proxy.conf.json)이 경로를 그대로 유지해 `127.0.0.1:9966`으로 전달합니다. Spring이 보호자를 저장하고 생성된 ID를 응답합니다. 프론트 코드에 EC2 주소나 DB 접속 정보가 필요하지 않습니다.

## 2. 처음 실행하기 — AWS·PostgreSQL 없이

**준비물:** Git, JDK 21, Node.js 24.x와 npm. Maven은 저장소에 포함된 Wrapper를 사용합니다. 아래 명령은 Bash 기준이며, Windows에서는 `./mvnw` 대신 `mvnw.cmd`를 사용할 수 있습니다.

```bash
git clone https://github.com/bespinglobal-finalproject-kdt5/petclinic-eks-app.git
cd petclinic-eks-app
```

**터미널 1 — REST부터 시작합니다.** 처음 실행할 때는 Maven 의존성을 내려받습니다.

```bash
cd petclinic-rest
./mvnw spring-boot:run
```

**터미널 2 — 새 터미널을 저장소 루트에서 열고 WEB을 시작합니다.**

```bash
cd petclinic-angular
npm ci
npm start
```

브라우저에서 **<http://localhost:4200/>** 을 엽니다. 두 프로세스가 모두 떠 있어야 목록 조회와 저장이 가능합니다. 종료할 때는 각 터미널에서 `Ctrl+C`를 누르세요. 기본 H2 모드에서는 REST를 종료하면 새로 입력한 데이터가 사라집니다.

### 실행 확인

```bash
# ① REST가 요청을 받을 준비가 됐는지 확인: status가 UP이어야 합니다.
curl -fsS http://localhost:9966/petclinic/actuator/health/readiness

# ② 브라우저와 같은 경로로 확인: Angular 프록시를 거쳐 JSON 페이지를 반환해야 합니다.
curl -fsS 'http://localhost:4200/petclinic/api/v2/owners?page=0&size=1'
```

API 주소·요청 필드·응답 형식은 실행 중인 [로컬 Swagger UI](http://localhost:9966/petclinic/swagger-ui.html) 또는 [OpenAPI 명세](petclinic-rest/src/main/resources/openapi.yml)에서 확인할 수 있습니다.

## 3. 화면에서 무엇을 해볼 수 있나요?

| 메뉴·화면 | 기능 |
|---|---|
| Owners | 성으로 보호자 검색, 신규 등록, 상세 조회 및 연락처 수정 |
| 보호자 상세 → Pets / Visits | 보호자에게 반려동물 추가, 반려동물 정보 수정, 방문 기록 등록·수정·삭제 |
| Veterinarians / Specialties | 수의사와 전문 분야 관리 |
| Pet Types | 개·고양이 등 등록 폼에서 선택할 동물 종류 관리 |

**첫 실습:** `Owners → Add Owner`에서 가상 보호자를 등록하고 성으로 검색하세요. 상세 화면에서 `Add New Pet`으로 반려동물을 추가한 뒤 `Add Visit`으로 방문 기록을 남기면, 보호자 → 반려동물 → 방문 기록의 관계를 확인할 수 있습니다. 전화번호는 구분자 없이 **숫자 10자리**입니다. 빈 DB라 종류를 선택할 수 없으면 `Pet Types`에서 종류를 먼저 추가하세요. 기본 설정은 사용자 인증이 꺼져 있으므로 **실제 이름·주소·전화번호 대신 가상 데이터만** 사용하세요.

## 4. H2 대신 PostgreSQL 사용하기

로컬 화면 확인에는 H2로 충분합니다. 재시작 후에도 데이터를 유지하거나 외부 DB와 연동을 시험할 때만 `external-postgres` 프로필을 선택하세요.

1. PostgreSQL에 DB와 접속 계정을 준비합니다. **새 빈 개발 DB**라면 관리자 또는 마이그레이션 계정으로 [schema.sql](petclinic-rest/src/main/resources/db/postgres/schema.sql)을 한 번 적용하고 앱 계정에 필요한 테이블·시퀀스 권한을 부여합니다. 기존 데이터가 있는 DB에는 초기화 스크립트를 그대로 재실행하지 마세요.
2. REST 터미널에 아래 값을 설정한 뒤 재시작합니다. `POSTGRES_URL`은 일반 웹 주소가 아니라 **JDBC URL**입니다.

```bash
# petclinic-rest/에서 실행하는 로컬 PostgreSQL 예시
export SPRING_PROFILES_ACTIVE=external-postgres
export POSTGRES_URL='jdbc:postgresql://localhost:5432/petclinic'
export POSTGRES_USER='petclinic_app'
read -rsp 'PostgreSQL password: ' POSTGRES_PASS; echo
export POSTGRES_PASS
./mvnw spring-boot:run
```

이 프로필은 `spring.sql.init.mode=never`, `spring.jpa.hibernate.ddl-auto=validate`입니다. 즉, **앱은 스키마를 만들거나 샘플 데이터를 넣지 않고, 준비된 스키마가 맞는지만 검사**합니다. 원격 DB는 신뢰할 수 있는 CA로 호스트 이름까지 검증하는 TLS 연결(`sslmode=verify-full`)을 사용하고 비밀번호는 Git에 넣지 마세요. 기본 H2 모드로 돌아가려면 위 프로세스를 종료하고 `unset SPRING_PROFILES_ACTIVE POSTGRES_URL POSTGRES_USER POSTGRES_PASS` 후 다시 실행합니다.

## 5. 기존 소스에서 바뀐 부분

| 파일 | 변경 내용과 이유 |
|---|---|
| [Angular 개발 환경](petclinic-angular/src/environments/environment.ts) / [프로덕션 환경](petclinic-angular/src/environments/environment.prod.ts) | API 주소를 `http://localhost:9966/...` 대신 `/petclinic/api/`로 사용합니다. 배포된 화면이 방문자 PC의 `localhost`에 요청을 보내는 문제를 막습니다. |
| [Angular CLI 설정](petclinic-angular/angular.json) / [개발 프록시](petclinic-angular/proxy.conf.json) | `npm start`에서 같은 출처로 들어온 API 요청을 로컬 REST에 전달합니다. 이 프록시는 프로덕션 빌드에 포함되지 않습니다. |
| [index.html](petclinic-angular/src/index.html) / [Nginx 설정](petclinic-angular/nginx.conf) | 화면을 `/`에서 제공하도록 기본 경로를 맞췄습니다. Nginx는 `8080`에서 프론트 경로 새로고침을 `index.html`로 처리하지만 API를 대신 처리하지 않습니다. 실제 배포 시 `/petclinic/api/*`는 별도로 REST에 라우팅해야 합니다. |
| [Spring 기본 설정](petclinic-rest/src/main/resources/application.properties) / [외부 PostgreSQL 설정](petclinic-rest/src/main/resources/application-external-postgres.properties) | H2 실행은 유지하고, 외부 PostgreSQL 설정과 liveness/readiness 상태 검사 경로를 추가했습니다. DB 주소·계정·암호를 앱 소스에 고정하지 않습니다. |

## 6. 테스트와 빌드

각 명령 묶음은 **저장소 루트**에서 시작합니다. Angular 의존성은 먼저 `npm ci`로 설치하세요.

```bash
cd petclinic-angular
npm run test:ci                       # 단위 테스트를 한 번 실행
npm run build -- --configuration production  # 정적 웹 파일 → dist/browser/
```

```bash
cd petclinic-rest
./mvnw test                           # REST 테스트
./mvnw package                        # 테스트 후 실행 가능한 JAR → target/
```

## 7. 자주 막히는 지점

| 증상 | 확인할 것 |
|---|---|
| 화면은 열리지만 목록이 안 나오거나 프록시 오류가 납니다. | 위 실행 확인 ① → ② 순서로 호출하세요. ①부터 실패하면 REST의 기동 로그·9966 포트를, ①만 성공하면 Angular 프록시 대상과 요청 경로를 확인하세요. |
| 빈 PostgreSQL에서 `/petclinic/api/owners`가 `404`입니다. | 기존 목록 API는 결과가 없을 때도 404를 반환합니다. `/petclinic/api/v2/owners?page=0&size=1`의 `content`와 `totalElements`로 연결 여부와 데이터 유무를 구분하세요. |
| PostgreSQL 프로필에서 시작하자마자 실패합니다. | 접속 환경변수, DB·스키마 존재 여부, 앱 계정 권한을 확인하세요. `validate`는 없는 테이블을 자동 생성하지 않습니다. |

**관련 자료:** [Angular 상세 README](petclinic-angular/README.md) · [REST 상세 README](petclinic-rest/readme.md) · [앱 소스 보존 커밋과 당시 인프라 구성](https://github.com/bespinglobal-finalproject-kdt5/petclinic-infra/tree/a306bdcf293ecba5cff81fcd6b32deabcb5db98b). 하위 README에는 원본 프로젝트의 Docker 안내도 남아 있지만, 이 저장소에는 해당 배포 파일이 없습니다. 각 앱의 기존 저작권 고지와 라이선스를 유지합니다.
