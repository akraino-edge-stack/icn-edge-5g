/*
Copyright 2021.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	_ "io/ioutil"
	"log"
	"net/http"
	"reflect"

	"github.com/go-logr/logr"
	errs "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	_ "sigs.k8s.io/controller-runtime/pkg/log"

	"github.com/free5gc/openapi/models"
	slicev1alpha1 "slice.free5gc.io/webui/api/v1alpha1"
)

// MobilesubscriberReconciler reconciles a Mobilesubscriber object
type MobilesubscriberReconciler struct {
	client.Client
	Log    logr.Logger
	Scheme *runtime.Scheme
}

type FlowRule struct {
	Filter string `json:"filter,omitempty" yaml:"filter" bson:"filter" mapstructure:"filter"`
	Snssai string `json:"snssai,omitempty" yaml:"snssai" bson:"snssai" mapstructure:"snssai"`
	Dnn    string `json:"dnn,omitempty" yaml:"v" bson:"dnn" mapstructure:"dnn"`
	Var5QI int    `json:"5qi,omitempty" yaml:"5qi" bson:"5qi" mapstructure:"5qi"`
	MBRUL  string `json:"mbrUL,omitempty" yaml:"mbrUL" bson:"mbrUL" mapstructure:"mbrUL"`
	MBRDL  string `json:"mbrDL,omitempty" yaml:"mbrDL" bson:"mbrDL" mapstructure:"mbrDL"`
	GBRUL  string `json:"gbrUL,omitempty" yaml:"gbrUL" bson:"gbrUL" mapstructure:"gbrUL"`
	GBRDL  string `json:"gbrDL,omitempty" yaml:"gbrDL" bson:"gbrDL" mapstructure:"gbrDL"`
}

type SubsData struct {
	PlmnID                            string                                     `json:"plmnID"`
	UeId                              string                                     `json:"ueId"`
	AuthenticationSubscription        models.AuthenticationSubscription          `json:"AuthenticationSubscription"`
	AccessAndMobilitySubscriptionData models.AccessAndMobilitySubscriptionData   `json:"AccessAndMobilitySubscriptionData"`
	SessionManagementSubscriptionData []models.SessionManagementSubscriptionData `json:"SessionManagementSubscriptionData"`
	SmfSelectionSubscriptionData      models.SmfSelectionSubscriptionData        `json:"SmfSelectionSubscriptionData"`
	AmPolicyData                      models.AmPolicyData                        `json:"AmPolicyData"`
	SmPolicyData                      models.SmPolicyData                        `json:"SmPolicyData"`
	FlowRules                         []FlowRule                                 `json:"FlowRules"`
}

func getSample() SubsData {
	resp, err := http.Get("http://f5gc-webui.default.svc.cluster.local:5000/api/sample")
	if err != nil {
		log.Fatalln(err)
	}
	defer resp.Body.Close()
	var subs SubsData
	if err := json.NewDecoder(resp.Body).Decode(&subs); err != nil {
		log.Fatal("ooopsss! an error occurred, please try again")
	}
	log.Printf("subsData: %v\n", subs)
	return subs
	//body, err := ioutil.ReadAll(resp.Body)
	//if err != nil {
	//	log.Fatalln(err)
	//}
	//sb := string(body)
	//log.Printf(sb)
	//return sb
}

func putSubStruct(sub *slicev1alpha1.Mobilesubscriber) SubsData {
	var subsData SubsData
	var OpVal, OpcVal string
	if sub.Spec.OpType == "OP" {
		OpVal = sub.Spec.OpValue
		OpcVal = ""
	} else {
		OpVal = ""
		OpcVal = sub.Spec.OpValue
	}
	authSubsData := models.AuthenticationSubscription{
		AuthenticationManagementField: "8000",
		AuthenticationMethod:          models.AuthMethod(sub.Spec.AuthMethod), // "5G_AKA", "EAP_AKA_PRIME"
		Milenage: &models.Milenage{
			Op: &models.Op{
				EncryptionAlgorithm: 0,
				EncryptionKey:       0,
				OpValue:             OpVal, // Required
			},
		},
		Opc: &models.Opc{
			EncryptionAlgorithm: 0,
			EncryptionKey:       0,
			OpcValue:            OpcVal, // Required
		},
		PermanentKey: &models.PermanentKey{
			EncryptionAlgorithm: 0,
			EncryptionKey:       0,
			PermanentKeyValue:   sub.Spec.AuthKey, // Required
		},
		SequenceNumber: "16f3b3f70fc2",
	}
	amDataData := models.AccessAndMobilitySubscriptionData{
		Gpsis: []string{
			"msisdn-0900000000",
		},
		Nssai: &models.Nssai{
			DefaultSingleNssais: []models.Snssai{
				{
					Sd:  sub.Spec.SNSSAI[0].SD,
					Sst: sub.Spec.SNSSAI[0].SST,
				},
				{
					Sd:  sub.Spec.SNSSAI[1].SD,
					Sst: sub.Spec.SNSSAI[1].SST,
				},
			},
			SingleNssais: []models.Snssai{
				{
					Sd:  sub.Spec.SNSSAI[0].SD,
					Sst: sub.Spec.SNSSAI[0].SST,
				},
				{
					Sd:  sub.Spec.SNSSAI[1].SD,
					Sst: sub.Spec.SNSSAI[1].SST,
				},
			},
		},
		SubscribedUeAmbr: &models.AmbrRm{
			Downlink: "2 Gbps",
			Uplink:   "1 Gbps",
		},
	}
	smDataData := []models.SessionManagementSubscriptionData{
		{
			SingleNssai: &models.Snssai{
				Sst: sub.Spec.SNSSAI[0].SST,
				Sd:  sub.Spec.SNSSAI[0].SD,
			},
			DnnConfigurations: map[string]models.DnnConfiguration{
				sub.Spec.SNSSAI[0].DNN[0].Name: {
					PduSessionTypes: &models.PduSessionTypes{
						DefaultSessionType:  models.PduSessionType_IPV4,
						AllowedSessionTypes: []models.PduSessionType{models.PduSessionType_IPV4},
					},
					SscModes: &models.SscModes{
						DefaultSscMode:  models.SscMode__1,
						AllowedSscModes: []models.SscMode{models.SscMode__1},
					},
					SessionAmbr: &models.Ambr{
						Downlink: sub.Spec.SNSSAI[0].DNN[0].AMBR.Downlink,
						Uplink:   sub.Spec.SNSSAI[0].DNN[0].AMBR.Uplink,
					},
					Var5gQosProfile: &models.SubscribedDefaultQos{
						Var5qi: sub.Spec.SNSSAI[0].DNN[0].QIVal,
						Arp: &models.Arp{
							PriorityLevel: 8,
						},
						PriorityLevel: 8,
					},
				},
				sub.Spec.SNSSAI[0].DNN[1].Name: {
					PduSessionTypes: &models.PduSessionTypes{
						DefaultSessionType:  models.PduSessionType_IPV4,
						AllowedSessionTypes: []models.PduSessionType{models.PduSessionType_IPV4},
					},
					SscModes: &models.SscModes{
						DefaultSscMode:  models.SscMode__1,
						AllowedSscModes: []models.SscMode{models.SscMode__1},
					},
					SessionAmbr: &models.Ambr{
						Downlink: sub.Spec.SNSSAI[0].DNN[1].AMBR.Downlink,
						Uplink:   sub.Spec.SNSSAI[0].DNN[1].AMBR.Uplink,
					},
					Var5gQosProfile: &models.SubscribedDefaultQos{
						Var5qi: sub.Spec.SNSSAI[0].DNN[1].QIVal,
						Arp: &models.Arp{
							PriorityLevel: 8,
						},
						PriorityLevel: 8,
					},
				},
			},
		},
		{
			SingleNssai: &models.Snssai{
				Sst: sub.Spec.SNSSAI[1].SST,
				Sd:  sub.Spec.SNSSAI[0].SD,
			},
			DnnConfigurations: map[string]models.DnnConfiguration{
				sub.Spec.SNSSAI[1].DNN[0].Name: {
					PduSessionTypes: &models.PduSessionTypes{
						DefaultSessionType:  models.PduSessionType_IPV4,
						AllowedSessionTypes: []models.PduSessionType{models.PduSessionType_IPV4},
					},
					SscModes: &models.SscModes{
						DefaultSscMode:  models.SscMode__1,
						AllowedSscModes: []models.SscMode{models.SscMode__1},
					},
					SessionAmbr: &models.Ambr{
						Downlink: sub.Spec.SNSSAI[1].DNN[0].AMBR.Downlink,
						Uplink:   sub.Spec.SNSSAI[1].DNN[0].AMBR.Uplink,
					},
					Var5gQosProfile: &models.SubscribedDefaultQos{
						Var5qi: sub.Spec.SNSSAI[1].DNN[0].QIVal,
						Arp: &models.Arp{
							PriorityLevel: 8,
						},
						PriorityLevel: 8,
					},
				},
				sub.Spec.SNSSAI[1].DNN[1].Name: {
					PduSessionTypes: &models.PduSessionTypes{
						DefaultSessionType:  models.PduSessionType_IPV4,
						AllowedSessionTypes: []models.PduSessionType{models.PduSessionType_IPV4},
					},
					SscModes: &models.SscModes{
						DefaultSscMode:  models.SscMode__1,
						AllowedSscModes: []models.SscMode{models.SscMode__1},
					},
					SessionAmbr: &models.Ambr{
						Downlink: sub.Spec.SNSSAI[1].DNN[1].AMBR.Downlink,
						Uplink:   sub.Spec.SNSSAI[1].DNN[1].AMBR.Uplink,
					},
					Var5gQosProfile: &models.SubscribedDefaultQos{
						Var5qi: sub.Spec.SNSSAI[1].DNN[1].QIVal,
						Arp: &models.Arp{
							PriorityLevel: 8,
						},
						PriorityLevel: 8,
					},
				},
			},
		},
	}
	smfSelData := models.SmfSelectionSubscriptionData{
		SubscribedSnssaiInfos: map[string]models.SnssaiInfo{
			sub.Spec.SNSSAI[0].SD: {
				DnnInfos: []models.DnnInfo{
					{
						Dnn: "internet",
					},
				},
			},
			sub.Spec.SNSSAI[1].SD: {
				DnnInfos: []models.DnnInfo{
					{
						Dnn: "internet",
					},
				},
			},
		},
	}

	amPolicyData := models.AmPolicyData{
		SubscCats: []string{
			"free5gc",
		},
	}
	smPolicyData := models.SmPolicyData{
		SmPolicySnssaiData: map[string]models.SmPolicySnssaiData{
			"01010203": {
				Snssai: &models.Snssai{
					Sd:  sub.Spec.SNSSAI[0].SD,
					Sst: sub.Spec.SNSSAI[0].SST,
				},
				SmPolicyDnnData: map[string]models.SmPolicyDnnData{
					"internet": {
						Dnn: "internet",
					},
				},
			},
			"02010203": {
				Snssai: &models.Snssai{
					Sd:  sub.Spec.SNSSAI[1].SD,
					Sst: sub.Spec.SNSSAI[1].SST,
				},
				SmPolicyDnnData: map[string]models.SmPolicyDnnData{
					"internet": {
						Dnn: "internet",
					},
				},
			},
		},
	}
	servingPlmnId := sub.Spec.PLMNId
	ueId := "imsi-" + sub.Spec.SUPI

	subsData = SubsData{
		PlmnID:                            servingPlmnId,
		UeId:                              ueId,
		AuthenticationSubscription:        authSubsData,
		AccessAndMobilitySubscriptionData: amDataData,
		SessionManagementSubscriptionData: smDataData,
		SmfSelectionSubscriptionData:      smfSelData,
		AmPolicyData:                      amPolicyData,
		SmPolicyData:                      smPolicyData,
	}
	log.Printf("subData: %v\n", subsData)
	return subsData
}

func getSubscribers() ([]SubsData, error) {
	client := &http.Client{}
	subURL := "http://f5gc-webui.default.svc.cluster.local:5000/api/subscriber"
	req, err := http.NewRequest(http.MethodGet, subURL, nil)
	if err != nil {
		log.Println("Error in NewRequest...")
		return []SubsData{}, err
	}
	resp, err := client.Do(req)
	if err != nil {
		log.Println("Error in httpPut...")
		return []SubsData{}, err
	}
	defer resp.Body.Close()
	var subs []SubsData
	if err := json.NewDecoder(resp.Body).Decode(&subs); err != nil {
		log.Fatal("ooopsss! an error occurred, please try again")
	}
	log.Printf("Get subsData: %v\n", subs)
	fmt.Println(resp.StatusCode)
	return subs, nil
}

func putSubscriber(sub *slicev1alpha1.Mobilesubscriber) error {
	client := &http.Client{}
	subscriber := putSubStruct(sub)
	json, err := json.Marshal(subscriber)
	if err != nil {
		log.Println("Error in Marshaling...")
		return err
	}
	subURL := "http://f5gc-webui.default.svc.cluster.local:5000/api/subscriber/imsi-" + sub.Spec.SUPI + "/" + sub.Spec.PLMNId
	req, err := http.NewRequest(http.MethodPut, subURL, bytes.NewBuffer(json))
	if err != nil {
		log.Println("Error in NewRequest...")
		return err
	}
	req.Header.Set("Content-Type", "application/json; charset=utf-8")
	resp, err := client.Do(req)
	if err != nil {
		log.Println("Error in httpPut...")
		return err
	}
	defer resp.Body.Close()
	fmt.Println(resp.StatusCode)
	return err
}

func delSubscriber(sub *slicev1alpha1.Mobilesubscriber) error {
	client := &http.Client{}
	subURL := "http://f5gc-webui.default.svc.cluster.local:5000/api/subscriber/imsi-" + sub.Spec.SUPI + "/" + sub.Spec.PLMNId
	req, err := http.NewRequest(http.MethodDelete, subURL, nil)
	if err != nil {
		log.Println("Error in NewRequest...")
		return err
	}
	resp, err := client.Do(req)
	if err != nil {
		log.Println("Error in httpPut...")
		return err
	}

	defer resp.Body.Close()
	fmt.Println(resp.StatusCode)
	return err
}

func getDeletionTempstamp(instance runtime.Object) *metav1.Time {
	value := reflect.ValueOf(instance)
	field := reflect.Indirect(value).FieldByName("DeletionTimestamp")
	return field.Interface().(*metav1.Time)
}

func GetInstance(r *MobilesubscriberReconciler, ctx context.Context, req ctrl.Request) (runtime.Object, error) {
	msubscriber := &slicev1alpha1.Mobilesubscriber{}
	err := r.Get(ctx, req.NamespacedName, msubscriber)
	return msubscriber, err
}

func getFinalizers(instance runtime.Object) []string {
	value := reflect.ValueOf(instance)
	field := reflect.Indirect(value).FieldByName("Finalizers")
	return field.Interface().([]string)
}

func containsString(slice []string, s string) bool {
	for _, item := range slice {
		if item == s {
			return true
		}
	}
	return false
}

func removeString(slice []string, s string) (result []string) {
	for _, item := range slice {
		if item == s {
			continue
		}
		result = append(result, item)
	}
	return
}

func appendFinalizer(instance runtime.Object, item string) {
	value := reflect.ValueOf(instance)
	field := reflect.Indirect(value).FieldByName("ObjectMeta")
	base_obj := field.Interface().(metav1.ObjectMeta)
	base_obj.Finalizers = append(base_obj.Finalizers, item)
	field.Set(reflect.ValueOf(base_obj))
}
func removeFinalizer(instance runtime.Object, item string) {
	value := reflect.ValueOf(instance)
	field := reflect.Indirect(value).FieldByName("ObjectMeta")
	base_obj := field.Interface().(metav1.ObjectMeta)
	base_obj.Finalizers = removeString(base_obj.Finalizers, item)
	field.Set(reflect.ValueOf(base_obj))
}

//+kubebuilder:rbac:groups=slice.slice.free5gc.io,resources=mobilesubscribers,verbs=get;list;watch;create;update;patch;delete
//+kubebuilder:rbac:groups=slice.slice.free5gc.io,resources=mobilesubscribers/status,verbs=get;update;patch
//+kubebuilder:rbac:groups=slice.slice.free5gc.io,resources=mobilesubscribers/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the Mobilesubscriber object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.8.3/pkg/reconcile
func (r *MobilesubscriberReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {

	log := r.Log.WithValues("mobilesubscriber", req.NamespacedName)
	instance, err := GetInstance(r, ctx, req)
	if err != nil {
		if errs.IsNotFound(err) {
			// No instance
			return ctrl.Result{}, nil
		}
		log.Error(err, "unable to fetch MobileSubscriber")
		// we'll ignore not-found errors, since they can't be fixed by an immediate
		// requeue (we'll need to wait for a new notification), and we can get them
		// on deleted requests.
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}
	//log.Info("Rx Mobilesubscriber:" + msub.Spec.Name + msub.Spec.PLMNId + msub.Spec.SUPI)
	finalizerName := "rule.finalizers.httpcrd.akraino.org"
	delete_timestamp := getDeletionTempstamp(instance)
	msub := instance.(*slicev1alpha1.Mobilesubscriber)
	if delete_timestamp.IsZero() {
		log.Info("Creating mobilesubscriber")
		putSubscriber(msub)
		getSubscribers()
		finalizers := getFinalizers(instance)
		if !containsString(finalizers, finalizerName) {
			appendFinalizer(instance, finalizerName)
			if err := r.Update(ctx, msub); err != nil {
				return ctrl.Result{}, err
			}
			log.Info("Added finalizer for ")
		}

	} else {
		log.Info("Deleting mobilesubscriber")
		delSubscriber(msub)
		finalizers := getFinalizers(instance)
		if containsString(finalizers, finalizerName) {
			removeFinalizer(instance, finalizerName)
			if err := r.Update(ctx, msub); err != nil {
				return ctrl.Result{}, err
			}
		}
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.
func (r *MobilesubscriberReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&slicev1alpha1.Mobilesubscriber{}).
		Complete(r)
}
