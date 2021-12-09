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

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type FlowRule struct {
	IpFilter string `json:"ipFilter,omitempty"`
	// +kubebuilder:validation:Minimum:=0
	// +kubebuilder:validation:Maximum:=255
	QIVal int8   `json:"qiVal,omitempty"`
	MBRUL string `json:"mbrUL,omitempty"`
	MBRDL string `json:"mbrDL,omitempty"`
	GBRUL string `json:"gbrUL,omitempty"`
	GBRDL string `json:"gbrDL,omitempty"`
}

type AMBRConfig struct {
	Uplink   string `json:"uplink,omitempty"`
	Downlink string `json:"downlink,omitempty"`
}

type DNNConfig struct {
	Name string     `json:"name,omitempty"`
	AMBR AMBRConfig `json:"ambr,omitempty"`
	// +kubebuilder:validation:Minimum:=0
	// +kubebuilder:validation:Maximum:=255
	QIVal int32 `json:"qiVal,omitempty"`
	// +kubebuilder:validation:Optional
	Flow FlowRule `json:"flowRule,omitempty"`
}

type SNSSAIConfig struct {
	SST       int32  `json:"sst,omitempty"`
	SD        string `json:"sd,omitempty"`
	IsDefault bool   `json:"isDefault,omitempty"`
	// +kubebuilder:validation:MinItems:=1
	DNN []DNNConfig `json:"dnn,omitempty"`
}

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// MobilesubscriberSpec defines the desired state of Mobilesubscriber
type MobilesubscriberSpec struct {
	// Important: Run "make" to regenerate code after modifying this file
	Name   string `json:"name,omitempty"`
	PLMNId string `json:"plmnid,omitempty"`
	// +kubebuilder:default="208930000000003"
	SUPI string `json:"supi,omitempty"`
	// +kubebuilder:validation:Enum="5G_AKA";"EAP_AKA_PRIME"
	// +kubebuilder:default:="5G_AKA"
	AuthMethod string `json:"authMethod,omitempty"`
	// +kubebuilder:validation:Optional
	// +kubebuilder:default:="8baf473f2f8fd09487cccbd7097c6862"
	AuthKey string `json:"authKey,omitempty"`
	// +kubebuilder:validation:Enum="OP";"OPc"
	// +kubebuilder:default:="OP"
	OpType string `json:"opType,omitempty"`
	// +kubebuilder:default:="8e27b6af0e692e750f32667a3b14605d"
	OpValue string `json:"opValue,omitempty"`
	// +kubebuilder:validation:MinItems:=2
	SNSSAI []SNSSAIConfig `json:"snssai,omitempty"`
}

// MobilesubscriberStatus defines the observed state of Mobilesubscriber
type MobilesubscriberStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// Mobilesubscriber is the Schema for the mobilesubscribers API
type Mobilesubscriber struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   MobilesubscriberSpec   `json:"spec,omitempty"`
	Status MobilesubscriberStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// MobilesubscriberList contains a list of Mobilesubscriber
type MobilesubscriberList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Mobilesubscriber `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Mobilesubscriber{}, &MobilesubscriberList{})
}
