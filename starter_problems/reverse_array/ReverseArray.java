/*
* Class: ReverseArray
* 
* Simple Java program to reverse an array
*/

import java.io.*;
 
class ReverseArray {
 
    /* 
     * Function: revereseArray
     * Inputs: 
     *        Integer-array arr
     *        Integer start
     *        Integer end
     * Outputs:
     *        Inplace reversed array
     * Recursive Function that reverses the input arr[] in place 
     * from position start to end; exits when start meets end
     */
    static void revereseArray(int arr[], int start, int end)
    {
        if (start >= end)
            return;
        // Swap in-place
        arr[start] = arr[start] + arr[end];
        arr[end]   = arr[start] - arr[end];
        arr[start] = arr[start] - arr[end]
        // recursive calls
        revereseArray(arr, start+1, end-1);
    }
 
    /* Function: printArray
     * Inputs: 
     *       Integer array arr
     *       Integer size
     * Functionality: As a utility that prints the array
     *           
     */
    static void printArray(int arr[], int size)
    {
        for (int i=0; i < size; i++)
            System.out.print(arr[i] + " ");
        System.out.println("");
    }
 
    /* 
     * Test function: main to check a sample array
     */
    public static void main (String[] args) {
        int arr[] = {1, 2, 3, 4, 5, 6};
        printArray(arr, arr.length);
        revereseArray(arr, 0,((arr.length)-1));
        System.out.println("Reversed array is: ");
        printArray(arr, arr.length);
    }
}
