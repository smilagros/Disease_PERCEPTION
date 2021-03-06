## CODE FOR THE DIFFERENTIAL EXPRESSION ANALYSIS OF EACH CASE SAMPLE AGAINST ALL THE CONTROL SAMPLES FROM THE SAME STUDY ##
## Developed by Jon Sanchez-Valle
## Barcelona Supercomputing Center
## Life Science Department
## Computational Biology Group
## Email: jon.sanchez@bsc.es

## load the essential packages 
library("affy");library(frma);library("limma");library("genefilter");require(graphics);library("hgu133plus2frmavecs");library("massiR");library("hgu133plus2.db")
library("cluster");library("NbClust");library(e1071)
## generate required directories


if ("New_ToptableIQR"%in%list.files("Data/") == FALSE){dir.create("Data/New_ToptableIQR")}
if ("New_ExpressionSet_Together"%in%list.files("Data/") == FALSE){dir.create("Data/New_ExpressionSet_Together")}
if ("New_ExpressionGenes_Together"%in%list.files("Data/") == FALSE){dir.create("Data/New_ExpressionGenes_Together")}
if ("New_Correspondences"%in%list.files("Data/") == FALSE){dir.create("Data/New_Correspondences")}
if ("New_PatientIQR"%in%list.files("Data/") == FALSE){dir.create("Data/New_PatientIQR")}
if ("New_Patienttvalues"%in%list.files("Data/") == FALSE){dir.create("Data/New_Patienttvalues")}
if ("New_ExpressionSetfiles"%in%list.files("Data/") == FALSE){dir.create("Data/New_ExpressionSetfiles")}


## set seed ##
## @@ @@ @@ ##
set.seed(1)

## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@  @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##
##                       Generate gene expression matrices for each disease separated by studies                      ##
## conduct differential expression analyses comparing in each study all the case samples with all the control samples ##
## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@  @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##

rawdatadir<-"./Data/New_Raw_data/"
rawdatafiles<-list.files(rawdatadir)
## load gene symbol - probe association and the probes that must be removed 
load("Data/Remove_Symbols_u133plus2.Rdata") # remo
load("Data/Gene_Symbols_u133plus2.Rdata") # simbolos
## indicate which diseases have been already analyzed 
if("New_Analyzed_diseases.txt"%in%list.files("Data/") == TRUE){echos<-read.table("Data/New_Analyzed_diseases.txt",stringsAsFactors = F)[,1];rawdatafiles<-setdiff(rawdatafiles,echos);dones<-echos}
if("New_Analyzed_diseases.txt"%in%list.files("Data/") == FALSE){dones<-c()}
print("We start the loop!")
for (a in 1:length(rawdatafiles)){
  inicio<-Sys.time()
  ## print information regarding the dataset that is going to be analyzed
  print(paste(rawdatafiles[a],"Control:",length(list.files(paste("./",rawdatadir,"/",rawdatafiles[a],"/Control/",sep=""))),"Case:",
              length(list.files(paste("./",rawdatadir,"/",rawdatafiles[a],"/Case/",sep=""))),sep="      "))
  control<-list.files(paste("./",rawdatadir,"/",rawdatafiles[a],"/Control",sep=""))
  path_con<-paste(rawdatadir,rawdatafiles[a],"/Control/",control,sep="")
  case<-list.files(paste("./",rawdatadir,"/",rawdatafiles[a],"/Case",sep=""))
  path_ca<-paste(rawdatadir,rawdatafiles[a],"/Case/",case,sep="")
  path_read<-c(path_con, path_ca)
  controls<-cbind(control,rep("control",length(control)))
  cases<-cbind(case,rep("case",length(case)))
  targets<-rbind(controls, cases)
  affyBatch<-ReadAffy(filenames=path_read)
  expSet<-frma(affyBatch)
  save(expSet,file=paste("Data/New_ExpressionSetfiles/",rawdatafiles[a],".Rdata",sep=""))
  comoda<-t(as.data.frame(expSet))
  ## save the normalized expression matrix (with probes)
  save(comoda,file=paste("Data/New_ExpressionSet_Together/",rawdatafiles[a],".Rdata",sep=""))
  comoda1<-comoda[-length(comoda[,1]),]
  ## remove probes not associated to gene symbols
  comoda2<-comoda1[-remo,]
  coluna<-colnames(comoda2)
  genes<-unique(simbolos)
  expression<-c()
  ## convert the probes' expression matrix into a gene expression matrix, median values are calculated when seveeral probes refer to the same gene symbol
  for (c in 1:length(genes)){
    com<-which(simbolos==as.character(genes[c]))
    if (length(com)>1){
      iq<-apply(comoda[com,],2,median)
    }
    if (length(com)==1){
      iq<-comoda[com,]
    }
    expression<-rbind(expression,iq)
  }
  colnames(expression)<-coluna
  rownames(expression)<-genes
  columna<-c(control,case)
  ## change samples names
  newpatientnames<-c(paste("Control_",1:length(control),sep=""),paste("Patient_",1:length(case),sep=""))
  correspondencia<-cbind(columna,newpatientnames)
  colnames(correspondencia)<-c("Original_name","Patient_name")
  ## save patient name - sample ID information
  save(correspondencia,file=paste("Data/New_Correspondences/",rawdatafiles[a],".Rdata",sep=""))
  colnames(expression)<-newpatientnames
  controls<-cbind(paste("Control_",1:length(control),sep=""),rep("control",length(control)))
  cases<-cbind(paste("Patient_",1:length(case),sep=""),rep("case",length(case)))
  targets<-rbind(controls, cases)
  ## save gene expression matrix with the new names
  save(expression,file=paste("Data/New_ExpressionGenes_Together/",rawdatafiles[a],".Rdata",sep=""))
  ## conduct differential gene expression analysis using LIMMA
  design<-cbind(CONTROL=c(rep(1,length(control)),rep(0,length(case))), CASE=c(rep(0,length(control)),rep(1,length(case))))
  rownames(design)<-targets[,1]
  cont.matrix<-makeContrasts(CASEvsCONTROL=CASE-CONTROL,levels=design)
  ## get DEGs from IQR
  fit<-lmFit(expression,design)
  fit2<-contrasts.fit(fit, cont.matrix)
  fit2<-eBayes(fit2)
  toptableIQR<-topTable(fit2, number=length(fit$Amean), adjust.method="BH", sort.by="p")
  ## save all patient vs. all control differential expression results
  write.table(toptableIQR,paste("./Data/New_ToptableIQR/",rawdatafiles[a],".txt",sep=""),sep="\t",quote=F)
  print(paste(a,"  out of  ",length(rawdatafiles),":  ",rawdatafiles[a],sep=""))
  dones<-c(dones,rawdatafiles[a])
  ## save the name of the analyzed disease (with its' corresponding study)
  write.table(dones,"Data/New_Analyzed_diseases.txt",quote=F,col.names=F,row.names=F,sep="\t")
  final<-Sys.time()
  diferencia<-final-inicio
  print(diferencia)
}
print("Gene-expression matrices and global differential expression analyses finished!!")


## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##
## conduct differential expression analyses comparing each case sample with all the control samples from the same study ##
## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##

expresiondir<-c("Data/New_ExpressionGenes_Together/")
expresionfiles<-list.files(expresiondir)
nombrecitos<-gsub(".Rdata","",expresionfiles,fixed = T)
## avoid re-analyzing patients
if(length(list.files("Data/New_Patienttvalues/"))>0){
  pacientes<-list.files("Data/New_Patienttvalues/")
  if(length(pacientes)>0){
    hecho<-c()
    dones<-gsub("_Patient.+",".Rdata",pacientes)
    done<-unique(dones)
    for(a in done){
      load(paste(expresiondir,a,sep=""))
      if(length(which(dones==a))==length(grep("Patient",colnames(expression)))){
        hecho<-c(hecho,a)
      }
    }
  }
  if(length(pacientes)==0){
    hecho<-c()
  }
  expresionfiles<-setdiff(expresionfiles,hecho)
}
## start patient-specific differential expression analysis
for(a in 1:length(expresionfiles)){
  load(paste(expresiondir,expresionfiles[a],sep=""))
  patientes<-grep("Patient",colnames(expression))
  controles<-grep("Control",colnames(expression))
  for(b in 1:length(patientes)){
    expresion<-expression[,c(controles,patientes[b])]
    control<-colnames(expression)[controles]
    case<-colnames(expression)[patientes[b]]
    controls<-cbind(paste("Control_",1:length(control),sep=""),rep("control",length(control)))
    cases<-cbind(paste("Patient_",1:length(case),sep=""),rep("case",length(case)))
    targets<-rbind(controls, cases)
    design<-cbind(CONTROL=c(rep(1,length(control)),rep(0,length(case))), CASE=c(rep(0,length(control)),rep(1,length(case))))
    rownames(design)<-targets[,1]
    cont.matrix<-makeContrasts(CASEvsCONTROL=CASE-CONTROL,levels=design)
    fit<-lmFit(expresion,design)  ##getting DEGs from IQR
    fit2<-contrasts.fit(fit, cont.matrix)
    fit2<-eBayes(fit2)
    toptableIQR<-topTable(fit2, number=length(fit$Amean), adjust.method="BH", sort.by="p")
    write.table(toptableIQR,paste("./Data/New_PatientIQR/",gsub(".Rdata","",expresionfiles[a]),"_",case,".txt",sep=""),sep="\t",quote=F)
    tvalues<-toptableIQR[,3]
    names(tvalues)<-rownames(toptableIQR)
    save(tvalues,file=paste("./Data/New_Patienttvalues/",gsub(".Rdata","",expresionfiles[a]),"_",case,".Rdata",sep=""))
  }
  print(paste(expresionfiles[a],"  we have finished  ",a,"  out of  ",length(expresionfiles),sep=""))
}
print("Patient-specific differential gene expression finished!!")


## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##
## Extract top X up- and down-regulated genes and generate a matrix of tvalues for LINCS analysis ##
## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##
topini<-Sys.time()
directory<-"Data/New_Patienttvalues/"
## indicate the number of DEG we want to select
seleccion<-500
patients<-list.files(directory)
nombres<-gsub(".Rdata","",patients,fixed=T)
## avoid re-analyzing patients
if (paste("New_Top_",seleccion,"_sDEGs.Rdata",sep="")%in%list.files("Data/") == TRUE){
  load(paste("Data/New_Top_",seleccion,"_sDEGs.Rdata",sep=""))
  hechos<-paste(names(sdegs),".Rdata",sep="")
  echos<-names(sdegs)
  patients<-setdiff(patients,hechos)
  nombres<-setdiff(nombres,echos) ; print("We do have sDEGs")
}
if (paste("New_Top_",seleccion,"_sDEGs.Rdata",sep="")%in%list.files("Data/") == FALSE){sdegs<-list() ; print("We do not have sDEGs")}
## select the up- and down-regulated genes
if(length(patients)>0){
  load(paste(directory,patients[1],sep=""))
  genes<-names(tvalues)
  tablatvalores<-c()
  for(a in 1:length(patients)){
    # a<-1
    load(paste(directory,patients[a],sep=""))
    tablatvalores<-cbind(tablatvalores,as.numeric(tvalues[genes]))
    tvalores<-sort(tvalues)
    sdegs[[nombres[a]]]$down<-tvalores[1:seleccion]
    sdegs[[nombres[a]]]$up<-tvalores[(length(tvalores)-(seleccion-1)):length(tvalores)]
    print(paste(a,"  out of  ",length(patients),"  patients",sep=""))
  }
  rownames(tablatvalores)<-genes
  colnames(tablatvalores)<-nombres
  save(sdegs,file=paste("Data/New_Top_",seleccion,"_sDEGs.Rdata",sep=""))
  # saveRDS(tablatvalores,file="Data/LINCS_tvalues_patients.rds")
  print(paste("Top ",seleccion,"genes selected!!",sep="  "))
}
topfin<-Sys.time()
print(topfin-topini)


## @@ @@ @@ @@ @@ @ @@ @@ @@ @@ @@ ##
## Generate a list with DEGs names ##
## @@ @@ @@ @@ @@ @ @@ @@ @@ @@ @@ ##
## duration: 1.329571 mins
indeg<-Sys.time()
patients<-list.files(directory)
nombres<-gsub(".Rdata","",patients,fixed=T)
## avoid re-analyzing patients
if (paste("New_Top_",seleccion,"_sDEGs_names.Rdata",sep="")%in%list.files("Data/") == FALSE){degs<-list() ; print("We do not have the list with sDEGs names")}
if (paste("New_Top_",seleccion,"_sDEGs_names.Rdata",sep="")%in%list.files("Data/") == TRUE){
  load(paste("Data/New_Top_",seleccion,"_sDEGs_names.Rdata",sep=""))
  hechos<-paste(names(degs),".Rdata",sep="")
  echos<-names(degs)
  patients<-setdiff(patients,hechos)
  nombres<-setdiff(nombres,echos)
  print("We have the list with sDEGs names")
}
## select the names of the up- and down-regulated genes
if(length(patients)>0){
  for(a in 1:length(patients)){
    load(paste(directory,patients[a],sep=""))
    tvalores<-sort(tvalues)
    degs[[nombres[a]]]$down<-names(tvalores[1:seleccion])
    degs[[nombres[a]]]$up<-names(tvalores[(length(tvalores)-(seleccion-1)):length(tvalores)])
    print(paste(a,"  out of  ",length(patients),"  finished",sep=""))
  }
  save(degs,file=paste("Data/New_Top_",seleccion,"_sDEGs_names.Rdata",sep=""))
}
fideg<-Sys.time()
print(fideg-indeg)
fisin<-Sys.time()
load(paste("Data/New_Top_",seleccion,"_sDEGs_names.Rdata",sep=""))


## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @ @ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##
## Generate a matrix of 1s, 0s and -1s with patients in rows and genes in columns ##
## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @ @ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##
## estimated duration: 2.74 hours
starting<-Sys.time()
patients<-list.files("Data/New_Patienttvalues/") ; nome<-gsub(".Rdata","",patients,fixed=T) ; onesandzerosm<-list()
for(a in 1:length(patients)){
  load(paste("Data/New_Patienttvalues/",patients[a],sep=""))
  updown<-rep(0,length(tvalues)) ; updown[1:500]<-(-1) ; updown[(length(updown)-(500-1)):length(updown)]<-1 ; names(updown)<-names(tvalues) ; onesandzerosm[[nome[a]]]<-updown
}
genes<-names(onesandzerosm[[1]])
newmatrix<-c()
for(a in 1:length(names(onesandzerosm))){newmatrix<-rbind(newmatrix,onesandzerosm[[a]][genes]) ; print(paste(a," out of ",length(names(onesandzerosm)),sep=""))}
rownames(newmatrix)<-nome
save(newmatrix,file="Data/New_Matrix_with_patients_and_genes_1_0_-1.Rdata")
finishing<-Sys.time() ; print(finishing-starting)

print("End of part 1")



## Calculate for each new patient their interactions ## 
## @ @ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @ @ ##
if("New_patients_fisher_overlaps.txt"%in%list.files()==TRUE){file.remove("New_patients_fisher_overlaps.txt")}
load("Data/New_Top_500_sDEGs_names.Rdata")
ndegs<-degs
load("Data/Top_500_sDEGs_names.Rdata")
background<-20502
fisin<-Sys.time()
for (a in 1:length(names(ndegs))){
  positi1<-ndegs[[a]]$up ; negati1<-ndegs[[a]]$down ; pega<-c() ; pegados<-c()
  for (b in 1:length(names(degs))){
    positi2<-degs[[b]]$up ; negati2<-degs[[b]]$down
    interspd <- length(intersect(positi1,positi2))
    kkpd <- matrix(c(interspd,length(positi1)-interspd,length(positi2)-interspd,background+interspd-length(positi1)-length(positi2)),nrow=2,ncol=2)
    fispd<-fisher.test(kkpd,alternative="greater") $p.value
    intersnd <- length(intersect(negati1,negati2))
    kknd <- matrix(c(intersnd,length(negati1)-intersnd,length(negati2)-intersnd,background+intersnd-length(negati1)-length(negati2)),nrow=2,ncol=2)
    fisnd<-fisher.test(kknd,alternative="greater") $p.value
    interspi <- length(intersect(positi1,negati2))
    kkpi <- matrix(c(interspi,length(positi1)-interspi,length(negati2)-interspi,background+interspi-length(positi1)-length(negati2)),nrow=2,ncol=2)
    fispi<-fisher.test(kkpi,alternative="greater") $p.value
    intersni <- length(intersect(negati1,positi2))
    kkni <- matrix(c(intersni,length(negati1)-intersni,length(positi2)-intersni,background+intersni-length(negati1)-length(positi2)),nrow=2,ncol=2)
    fisni<-fisher.test(kkni,alternative="greater") $p.value
    junt<-c(names(ndegs)[a],names(degs)[b],fispi,fispd,fisni,fisnd)
    jun<-t(junt)
    write.table(jun,"New_patients_fisher_overlaps.txt",quote=F,sep="\t",row.names=F,col.names=F,append = T)
  }
  print(a/length(names(ndegs)))
}
print("Finished!!") ; fisfin<-Sys.time() ; print(fisfin-fisin)

## read the file and generate the network
fis<-read.csv("New_patients_fisher_overlaps.txt",stringsAsFactors = F,sep="\t",header=F)
threshold<-0.0001
negs<-list("Pos_Neg"=which(fis[,3]<=threshold),"Neg_Pos"=which(fis[,5]<=threshold),"Pos_Pos"=which(fis[,4]>threshold),"Neg_Neg"=which(fis[,6]>threshold))
poss<-list("Pos_Neg"=which(fis[,3]>threshold),"Neg_Pos"=which(fis[,5]>threshold),"Pos_Pos"=which(fis[,4]<=threshold),"Neg_Neg"=which(fis[,6]<=threshold))
interactions<-rep(0,length(fis[,1])) ; interactions[Reduce(intersect,negs)]<--1 ; interactions[Reduce(intersect,poss)]<-1
## save the patient-patient similarity network including 0s
fisher_table<-cbind(fis[,1:2],interactions) ; colnames(fisher_table)<-c("Disease_1","Disease_2","Interaction")
save(fisher_table,file="Data/New_patients_similarities_with_the_original_set_of_patients.Rdata")
network<-fisher_table[which(fisher_table[,3]!=0),]
## save the generated "patient-patient similarity network"
write.table(network,"Networks/New_patients_similarities_with_the_original_ones_network.txt",sep="\t",quote=F,row.names=F)


## Classify new patients into their corresponding most probable disease ##
## @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ @@ ##
load("Data/Matrix_with_patients_and_genes_1_0_-1.Rdata")
patgen<-t(newmatrix)
load("Data/New_Matrix_with_patients_and_genes_1_0_-1.Rdata") #newmatrix
newpatgen<-t(newmatrix)
newpatgen<-newpatgen[rownames(patgen),]
gencasificados<-list()
gencasdif<-list()
for(a in 1:length(newpatgen[1,])){
  # a<-1
  # ini<-Sys.time()
  paciente<-as.numeric(newpatgen[,a])
  diferencias<-c()
  for(b in 1:length(patgen[1,])){
    compa<-as.numeric(patgen[,b])
    diferencias<-c(diferencias,dist(rbind(paciente,compa)))
  }
  names(diferencias)<-colnames(patgen)
  diferencias<-sort(diferencias)
  gencasificados[[colnames(newpatgen)[a]]]<-diferencias
  gencasdif[[colnames(newpatgen)[a]]]<-gsub("_.+","",names(diferencias))
  print(gsub("_.+","",names(diferencias))[1])
}
print("Ended!")

newpatclass<-c()
for(a in 1:length(names(gencasdif))){
  newpatclass<-rbind(newpatclass,c(names(gencasdif)[a],gencasdif[[a]][1]))
}




